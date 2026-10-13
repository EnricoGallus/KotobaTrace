require_relative "../../support/japanese_services"

RSpec.describe Japanese::MorphologicalAnalyzer do
  describe ".call" do
    it "retains raw positions, POS subtypes and conjugation metadata" do
      morphemes = described_class.call("政府は対応を促した。")
      expect(morphemes.map(&:position)).to eq((0...morphemes.length).to_a)
      verb = morphemes.find { |morpheme| morpheme.surface == "促し" }
      expect(verb.conjugation_type).not_to be_nil
      expect(verb.conjugation_form).not_to be_nil
      expect(morphemes.find { |morpheme| morpheme.surface == "は" }.pos_subtype1).to eq("係助詞")
    end

    it "normalizes missing feature values without dropping unknown words" do
      node = double(surface: "unknown", feature: "名詞,一般,*,*,*,*,*,*")
      allow(node).to receive_messages(is_bos?: false, is_eos?: false)
      mecab = double(enum_parse: [ node ])
      morpheme = described_class.new("unknown", mecab: mecab).call.first
      expect(morpheme.base_form).to eq("unknown")
      expect(morpheme.reading).to be_nil
      expect(morpheme.pos_subtype2).to be_nil
      expect(morpheme.conjugation_form).to be_nil
    end

    it "returns no tokens for empty text" do
      expect(described_class.call("")).to eq([])
    end

    it "preserves the complete input through its token surfaces" do
      text = "政府は対応を促した。"

      tokens = described_class.call(text)

      expect(tokens.map(&:surface).join).to eq(text)
    end

    it "normalizes a conjugated verb to its dictionary form" do
      tokens = described_class.call("政府は対応を促した。")

      token = tokens.find { |t| t.surface == "促し" }

      expect(token).not_to be_nil
      expect(token.base_form).to eq("促す")
      expect(token.part_of_speech).to eq("動詞")
    end

    it "keeps the past auxiliary separate from the verb" do
      tokens = described_class.call("政府は対応を促した。")

      expect(tokens.map(&:surface)).to include("促し", "た")

      auxiliary = tokens.find { |t| t.surface == "た" }

      expect(auxiliary.part_of_speech).to eq("助動詞")
    end

    it "normalizes a conjugated adjective" do
      tokens = described_class.call("増加が著しかった。")

      token = tokens.find { |t| t.base_form == "著しい" }

      expect(token).not_to be_nil
      expect(token.part_of_speech).to eq("形容詞")
    end

    it "provides a reading for a normal Japanese content word" do
      tokens = described_class.call("政府")

      token = tokens.find { |t| t.surface == "政府" }

      expect(token.reading).to eq("セイフ")
    end
  end
end

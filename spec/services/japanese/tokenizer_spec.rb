require "rails_helper"

RSpec.describe Japanese::Tokenizer do
  describe ".call" do
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

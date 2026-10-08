require "rails_helper"

RSpec.describe Japanese::Tokenizer do
  describe "compound segmentation" do
    compounds = [
      "社会保障",
      "社会保障制度",
      "少子高齢化",
      "劣等感",
      "海外旅行",
      "海外旅行離れ",
      "自己肯定感",
      "情報処理技術"
    ]

    compounds.each do |compound|
      it "preserves #{compound.inspect} through tokenization" do
        tokens = described_class.call(compound)

        expect(tokens.map(&:surface).join).to eq(compound)
      end
    end

    it "can display the current NAIST-jdic segmentation for inspection" do
      compounds.each do |compound|
        tokens = described_class.call(compound)

        next unless ENV["TOKEN_DEBUG"]

        warn "#{compound}: #{tokens.map(&:surface).join(' | ')}"
      end
    end
  end
end

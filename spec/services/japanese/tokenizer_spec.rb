require "rails_helper"

RSpec.describe Japanese::Tokenizer do
  describe ".call" do
    it "normalizes a conjugated verb to its dictionary form" do
      tokens = described_class.call("政府は対応を促した。")

      token = tokens.find { |t| t.surface.include?("促") }

      expect(token.base_form).to eq("促す")
    end

    it "normalizes a conjugated adjective" do
      tokens = described_class.call("増加が著しかった。")

      token = tokens.find { |t| t.surface.include?("著") }

      expect(token.base_form).to eq("著しい")
    end
  end
end

require "rails_helper"

RSpec.describe Anki::VocabularyIndex do
  let(:client) { instance_double(AnkiConnect::Client) }

  describe "#include?" do
    it "checks vocabulary loaded from Anki" do
      allow(client).to receive(:notes)
        .with(query: 'deck:"Vocabulary"')
        .and_return(
          [
            {
              "fields" => {
                "Expression" => {
                  "value" => "効く",
                  "order" => 0
                }
              }
            },
            {
              "fields" => {
                "Expression" => {
                  "value" => "血圧",
                  "order" => 0
                }
              }
            }
          ]
        )

      collection = described_class.new(client:)

      collection.scan(
        decks: ["Vocabulary"],
        expression_field: "Expression"
      )

      expect(collection).to include("効く")
      expect(collection).to include("血圧")
      expect(collection).not_to include("促す")
    end

    it "ignores notes without the configured expression field" do
      allow(client).to receive(:notes)
        .and_return(
          [
            {
              "fields" => {
                "Front" => {
                  "value" => "猫",
                  "order" => 0
                }
              }
            }
          ]
        )

      collection = described_class.new(client:)

      collection.scan(
        decks: ["Vocabulary"],
        expression_field: "Expression"
      )

      expect(collection).not_to include("猫")
    end

    it "ignores empty expressions" do
      allow(client).to receive(:notes)
        .and_return(
          [
            {
              "fields" => {
                "Expression" => {
                  "value" => "   ",
                  "order" => 0
                }
              }
            }
          ]
        )

      collection = described_class.new(client:)

      collection.scan(
        decks: ["Vocabulary"],
        expression_field: "Expression"
      )

      expect(collection).not_to include("")
    end

    it "requires the collection to be scanned first" do
      collection = described_class.new(client:)

      expect {
        collection.include?("効く")
      }.to raise_error("Collection has not been scanned")
    end
  end
end

require "rails_helper"

RSpec.describe Flashcards::VocabularyLookup do
  def lookup(**options)
    described_class.call(provider: "anki", deck: "Vocabulary", expression_field: "Expression", **options)
  end

  let(:client) { instance_double(AnkiConnect::Client) }

  before do
    allow(AnkiConnect::Client).to receive(:new).and_return(client)
  end

  it "returns a checked collection from the configured deck and field" do
    expect(client).to receive(:notes).with(query: 'deck:"Vocabulary"').and_return([
      { "fields" => { "Expression" => { "value" => " 猫 " } } }
    ])

    collection = lookup

    expect(collection).not_to be_unavailable
    expect(collection).to contain_exactly("猫")
    expect(collection).to include("猫")
    expect(collection).not_to include("犬")
    expect(collection).to be_checked
  end

  it "distinguishes a successful empty lookup from an unavailable provider" do
    allow(client).to receive(:notes).and_return([])

    collection = lookup

    expect(collection).to be_empty
    expect(collection).to be_checked
  end

  [ "none", "", "unsupported" ].each do |provider|
    it "returns an unchecked empty collection for provider #{provider.inspect}" do
      expect(AnkiConnect::Client).not_to receive(:new)

      collection = lookup(provider: provider)

      expect(collection).to be_empty
      expect(collection).not_to be_checked
      expect(collection).not_to include("猫")
    end
  end

  [ { deck: "" }, { expression_field: "" } ].each do |configuration|
    it "skips Anki when configuration is missing: #{configuration}" do
      expect(AnkiConnect::Client).not_to receive(:new)

      collection = lookup(**configuration)

      expect(collection).to be_empty
      expect(collection).not_to be_checked
    end
  end

  [
    AnkiConnect::TransportError.new("Connection refused", original_error: Errno::ECONNREFUSED.new),
    AnkiConnect::TransportError.new("Timed out", original_error: Net::ReadTimeout.new),
    AnkiConnect::APIError.new("Deck unavailable"),
    AnkiConnect::ProtocolError.new("Invalid response", body: "invalid"),
    KeyError.new("Malformed note")
  ].each do |error|
    it "returns an unchecked empty collection after #{error.class}: #{error.message}" do
      allow(client).to receive(:notes).and_raise(error)

      collection = lookup

      expect(collection).to be_empty
      expect(collection).not_to be_checked
      expect(collection).not_to include("猫")
      expect(collection).to be_unavailable
    end
  end

  it "also falls back when client initialization fails" do
    allow(AnkiConnect::Client).to receive(:new).and_raise(ArgumentError, "Invalid endpoint")

    collection = lookup

    expect(collection).to be_empty
    expect(collection).not_to be_checked
  end

  it "does not expose partial results when scanning fails" do
    allow(client).to receive(:notes).and_return([
      { "fields" => { "Expression" => { "value" => "猫" } } },
      {}
    ])

    collection = lookup

    expect(collection).to be_empty
    expect(collection).not_to be_checked
  end
end

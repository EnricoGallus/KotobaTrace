require "set"

module Anki
  class VocabularyIndex
    def initialize(client: AnkiConnect::Client.new(
        endpoint: ENV.fetch(
          "ANKI_CONNECT_URL",
          "http://127.0.0.1:8765"
        )
      )
    )
      @client = client
      @expressions = Set.new
      @scanned = false
    end

    def scan(decks:, expression_field:)
      @expressions.clear

      decks.each do |deck|
        notes = @client.notes(query: %(deck:"#{deck}"))

        notes.each do |note|
          field = note.fetch("fields")[expression_field]
          next unless field

          expression = field.fetch("value").strip
          next if expression.empty?

          @expressions << expression
        end
      end

      @scanned = true

      self
    end

    def include?(expression)
      raise "Collection has not been scanned" unless @scanned

      @expressions.include?(expression)
    end
  end
end
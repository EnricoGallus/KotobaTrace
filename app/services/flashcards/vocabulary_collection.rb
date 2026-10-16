require "set"

module Flashcards
  class VocabularyCollection
    include Enumerable

    attr_reader :provider

    def initialize(expressions = [], checked: false, unavailable: false, notes: {}, provider: nil)
      @expressions = Set.new(expressions)
      @checked = checked
      @unavailable = unavailable
      @notes = notes
      @provider = provider
    end

    delegate :each, :include?, :empty?, to: :@expressions

    def notes_for(expression)
      @notes.fetch(expression, [])
    end

    def unavailable?
      @unavailable
    end

    def checked?
      @checked
    end
  end
end

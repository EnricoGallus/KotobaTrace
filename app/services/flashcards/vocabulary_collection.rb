require "set"

module Flashcards
  class VocabularyCollection
    include Enumerable

    def initialize(expressions = [], checked: false, unavailable: false)
      @expressions = Set.new(expressions)
      @checked = checked
      @unavailable = unavailable
    end

    delegate :each, :include?, :empty?, to: :@expressions

    def unavailable?
      @unavailable
    end

    def checked?
      @checked
    end
  end
end

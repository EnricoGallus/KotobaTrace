require "set"

module Flashcards
  class VocabularyCollection
    include Enumerable

    def initialize(expressions = [], checked: false)
      @expressions = Set.new(expressions)
      @checked = checked
    end

    delegate :each, :include?, :empty?, to: :@expressions

    def checked?
      @checked
    end
  end
end

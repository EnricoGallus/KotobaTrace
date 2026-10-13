module Japanese
  module VocabularyRules
    class NumberCounter
      COMMON_COUNTERS = %w[分 時 日 月 年 人 回 枚 本 個 円 歳 階 件].freeze

      def self.call(morphemes, index)
        parts = []
        cursor = index
        while numeric?(morphemes[cursor])
          parts << morphemes[cursor]
          cursor += 1
        end
        return if parts.empty?
        return unless counter?(morphemes[cursor])

        parts << morphemes[cursor]
        VocabularyMatch.new(
          morphemes: parts, base_form: parts.map(&:surface).join,
          part_of_speech: "名詞", kind: :number
        )
      end

      def self.numeric?(morpheme)
        morpheme&.pos?("名詞") && morpheme.subtype?("数")
      end

      def self.counter?(morpheme)
        morpheme&.pos?("名詞") &&
          (morpheme.subtype?("助数詞") || COMMON_COUNTERS.include?(morpheme.surface))
      end

      private_class_method :numeric?, :counter?
    end
  end
end

module Japanese
  module VocabularyRules
    class TimeExpression
      UNITS = %w[秒 分 時 時間 日 週間 月 か月 ヶ月 年].freeze

      def self.call(morphemes, index)
        cursor = index
        while morphemes[cursor]&.pos?("名詞") && morphemes[cursor].subtype?("数")
          cursor += 1
        end
        return if cursor == index

        unit = morphemes[cursor]
        return unless unit&.pos?("名詞") && UNITS.include?(unit.surface)

        cursor += 1
        # Dictionaries may split 時間 into 時 + 間.
        if morphemes[cursor]&.pos?("名詞") && morphemes[cursor].surface == "間"
          cursor += 1
        end
        suffix = morphemes[cursor]
        return unless suffix&.pos?("名詞") && %w[前 後].include?(suffix.surface)

        parts = morphemes[index..cursor]
        VocabularyMatch.new(
          morphemes: parts, base_form: parts.map(&:surface).join,
          part_of_speech: "名詞", kind: :time_expression
        )
      end
    end
  end
end

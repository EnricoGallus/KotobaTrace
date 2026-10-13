module Japanese
  module VocabularyRules
    class NameHonorific
      HONORIFICS = %w[さん 様 ちゃん 君].freeze

      def self.call(morphemes, index)
        name, honorific = morphemes[index, 2]
        return unless name&.pos?("名詞") && name.subtype?("固有名詞")
        return unless honorific && HONORIFICS.include?(honorific.surface)

        VocabularyMatch.new(
          morphemes: [ name, honorific ], base_form: name.base_form,
          part_of_speech: "名詞", kind: :name
        )
      end
    end
  end
end

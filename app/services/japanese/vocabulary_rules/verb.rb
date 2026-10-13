module Japanese
  module VocabularyRules
    class Verb
      DIRECT_HELPERS = %w[れる られる せる させる くださる].freeze
      TE_HELPERS = %w[いる いく くる みる しまう おく ある くださる いただく もらう くれる].freeze

      def self.call(morphemes, index)
        head = morphemes[index]
        return unless head&.pos?("動詞")

        parts = [ head ]
        cursor = index + 1
        loop do
          following = morphemes[cursor]
          if following&.pos?("助動詞") || direct_helper?(following)
            parts << following
            cursor += 1
          elsif te_connector?(following) && te_helper?(morphemes[cursor + 1])
            parts.concat(morphemes[cursor, 2])
            cursor += 2
          else
            break
          end
        end

        VocabularyMatch.new(
          morphemes: parts, base_form: head.base_form,
          part_of_speech: "動詞", kind: :vocabulary
        )
      end

      def self.direct_helper?(morpheme)
        morpheme&.pos?("動詞") && DIRECT_HELPERS.include?(morpheme.base_form)
      end

      def self.te_connector?(morpheme)
        morpheme&.pos?("助詞") && morpheme.subtype?("接続助詞") &&
          %w[て で].include?(morpheme.surface)
      end

      def self.te_helper?(morpheme)
        morpheme&.pos?("動詞") && TE_HELPERS.include?(morpheme.base_form)
      end

      private_class_method :direct_helper?, :te_connector?, :te_helper?
    end
  end
end

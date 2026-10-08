require "natto"

module Japanese
  class Tokenizer
    Token = Data.define(
      :surface,
      :base_form,
      :reading,
      :part_of_speech
    )

    def self.call(text)
      new(text).call
    end

    def initialize(text, mecab: Natto::MeCab.new)
      @text = text
      @mecab = mecab
    end

    def call
      return [] if @text.blank?

      group_verbs(parse_tokens).reject do |token|
        token.part_of_speech == "記号" || token.part_of_speech == "助詞"
      end
    end

    private

    def parse_tokens
      @mecab.enum_parse(@text).filter_map do |node|
        next if node.is_bos? || node.is_eos?

        features = node.feature.split(",", -1)

        {
          surface: node.surface,
          base_form: normalize_feature(features[6], fallback: node.surface),
          reading: normalize_feature(features[7]),
          part_of_speech: normalize_feature(features[0]),
          pos_subtype: normalize_feature(features[1])
        }
      end
    end

    def group_verbs(tokens)
      result = []
      index = 0

      while index < tokens.length
        head = tokens[index]
        parts = [ head ]
        base_form = head[:base_form]
        part_of_speech = head[:part_of_speech]
        index += 1

        # 作成 + し → 作成する
        if suru_noun?(head) && suru_verb?(tokens[index])
          parts << tokens[index]
          index += 1
          base_form = "#{base_form}する"
          part_of_speech = "動詞"
        end

        if part_of_speech == "動詞"
          loop do
            following = tokens[index]

            if following&.dig(:part_of_speech) == "助動詞"
              # Attach endings such as た, ます, ない, たい.
              parts << following
              index += 1
            elsif te_iru_pair?(following, tokens[index + 1])
              # Attach て + いる or で + いる.
              parts.concat(tokens[index, 2])
              index += 2
            else
              break
            end
          end
        end

        readings = parts.map { |part| part[:reading] }

        result << Token.new(
          surface: parts.map { |part| part[:surface] }.join,
          base_form: base_form,
          reading: readings.all? ? readings.join : nil,
          part_of_speech: part_of_speech
        )
      end

      result
    end

    def suru_noun?(token)
      token[:part_of_speech] == "名詞" &&
        token[:pos_subtype] == "サ変接続"
    end

    def suru_verb?(token)
      token&.dig(:part_of_speech) == "動詞" &&
        token[:base_form] == "する"
    end

    def te_iru_pair?(particle, verb)
      particle&.dig(:part_of_speech) == "助詞" &&
        particle[:pos_subtype] == "接続助詞" &&
        %w[て で].include?(particle[:surface]) &&
        verb&.dig(:part_of_speech) == "動詞" &&
        verb[:pos_subtype] == "非自立" &&
        verb[:base_form] == "いる"
    end

    def normalize_feature(value, fallback: nil)
      return fallback if value.blank? || value == "*"

      value
    end
  end
end

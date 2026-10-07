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

      @mecab.enum_parse(@text).filter_map do |node|
        next if node.is_eos?

        features = node.feature.split(",", -1)

        Token.new(
          surface: node.surface,
          base_form: normalize_feature(features[6], fallback: node.surface),
          reading: normalize_feature(features[7]),
          part_of_speech: normalize_feature(features[0])
        )
      end
    end

    private

    def normalize_feature(value, fallback: nil)
      return fallback if value.blank? || value == "*"

      value
    end
  end
end

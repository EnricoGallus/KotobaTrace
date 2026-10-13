require "natto"

module Japanese
  class MorphologicalAnalyzer
    def self.call(text)
      new(text).call
    end

    def initialize(text, mecab: nil)
      @text = text
      @mecab = mecab
    end

    def call
      return [] if @text.blank?

      @mecab ||= Natto::MeCab.new
      position = 0
      @mecab.enum_parse(@text).filter_map do |node|
        next if node.is_bos? || node.is_eos?

        features = node.feature.split(",", -1)
        morpheme = Morpheme.new(
          surface: node.surface,
          base_form: normalize(features[6], fallback: node.surface),
          reading: normalize(features[7]),
          part_of_speech: normalize(features[0]),
          pos_subtype1: normalize(features[1]),
          pos_subtype2: normalize(features[2]),
          pos_subtype3: normalize(features[3]),
          conjugation_type: normalize(features[4]),
          conjugation_form: normalize(features[5]),
          position: position
        )
        position += 1
        morpheme
      end
    end

    private

    def normalize(value, fallback: nil)
      value.blank? || value == "*" ? fallback : value
    end
  end
end

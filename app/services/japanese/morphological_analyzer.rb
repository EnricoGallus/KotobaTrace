require "natto"
require "csv"

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

      options = {}
      options[:dicdir] = ENV["MECAB_DICDIR"] if ENV["MECAB_DICDIR"].present?
      @mecab ||= Natto::MeCab.new(options)
      position = 0
      source_cursor = 0
      @mecab.enum_parse(@text).filter_map do |node|
        next if node.is_bos? || node.is_eos?

        # NAIST optional trailing metadata contains unescaped XML quotes.
        features = CSV.parse_line(node.feature, liberal_parsing: true)
        # Character offsets preserve gaps that MeCab omits from its node list.
        start_offset = @text.index(node.surface, source_cursor)
        raise ArgumentError, "Token surface is missing from source text" unless start_offset
        source_cursor = start_offset + node.surface.length
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
          position: position,
          start_offset: start_offset,
          end_offset: source_cursor,
          unknown: node.is_unk?
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

module Japanese
  Morpheme = Data.define(
    :surface, :base_form, :reading, :part_of_speech,
    :pos_subtype1, :pos_subtype2, :pos_subtype3,
    :conjugation_type, :conjugation_form, :position,
    :start_offset, :end_offset, :unknown
  ) do
    def pos?(value)
      part_of_speech == value
    end

    def subtype?(value)
      [ pos_subtype1, pos_subtype2, pos_subtype3 ].include?(value)
    end
  end
end

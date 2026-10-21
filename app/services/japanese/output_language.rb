module Japanese
  module OutputLanguage
    NAMES = { "en" => "English", "ja" => "Japanese", "de" => "German", "vi" => "Vietnamese" }.freeze
    LABELS = { "en" => "English", "ja" => "日本語", "de" => "Deutsch", "vi" => "Tiếng Việt" }.freeze

    def self.normalize(value)
      NAMES.key?(value.to_s) ? value.to_s : "en"
    end
  end
end

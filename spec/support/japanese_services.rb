require "spec_helper"
require "active_support/core_ext/object/blank"
require_relative "../../app/services/japanese/morpheme"
require_relative "../../app/services/japanese/morphological_analyzer"
require_relative "../../app/services/japanese/vocabulary_candidate"
require_relative "../../app/services/japanese/vocabulary_match"
Dir[File.expand_path("../../app/services/japanese/vocabulary_rules/*.rb", __dir__)].sort.each { |path| require path }
require_relative "../../app/services/japanese/vocabulary_extractor"

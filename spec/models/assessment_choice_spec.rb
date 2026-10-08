require "rails_helper"

RSpec.describe AssessmentChoice, type: :model do
  describe "#label" do
    let(:choice) { described_class.new(key: "test_choice") }

    around do |example|
      original_backend = I18n.backend
      I18n.backend = I18n::Backend::Simple.new
      I18n.backend.store_translations(:en, assessment_choices: { test_choice: "Test choice" })
      I18n.backend.store_translations(:ja, assessment_choices: { test_choice: "テスト項目" })

      example.run
    ensure
      I18n.backend = original_backend
    end

    it "returns the translation for the current locale" do
      expect(I18n.with_locale(:en) { choice.label }).to eq("Test choice")
      expect(I18n.with_locale(:ja) { choice.label }).to eq("テスト項目")
    end
  end
end

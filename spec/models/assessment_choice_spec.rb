require "rails_helper"

RSpec.describe AssessmentChoice, type: :model do
  describe "#label" do
    let(:choice) { described_class.new(key: "known") }

    it "returns the translation for the current locale" do
      expect(I18n.with_locale(:en) { choice.label }).to eq("Know both")
      expect(I18n.with_locale(:ja) { choice.label }).to eq("読みも意味も知っている")
    end
  end
end

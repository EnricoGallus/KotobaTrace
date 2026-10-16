require 'rails_helper'

RSpec.describe WordAssessment, type: :model do
  it "casts the transient Anki value as a boolean" do
    assessment = described_class.new(in_flashcards: "false")

    expect(assessment.in_flashcards).to be(false)
  end
end

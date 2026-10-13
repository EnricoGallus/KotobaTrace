require 'rails_helper'

RSpec.describe WordAssessment, type: :model do
  it "casts the transient Anki value as a boolean" do
    assessment = described_class.new(in_anki: "false")

    expect(assessment.in_anki).to be(false)
  end
end

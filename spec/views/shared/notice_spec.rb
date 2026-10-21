require "rails_helper"

RSpec.describe "shared/_notice", type: :view do
  it "announces actionable failures as alerts" do
    render partial: "shared/notice", locals: { tone: "error", title: "Analysis failed", message: "Try again." }

    document = Nokogiri::HTML(rendered)
    expect(document.at_css('[role="alert"]').text).to include("Analysis failed", "Try again.")
  end

  it "keeps optional enrichment notices separate from urgent alerts" do
    render partial: "shared/notice", locals: { tone: "warning", title: "Flashcards unavailable", message: "Saving is still available." }

    document = Nokogiri::HTML(rendered)
    expect(document.at_css('[role="status"]').text).to include("Flashcards unavailable", "Saving is still available.")
    expect(document.css('[role="alert"]')).to be_empty
  end
end

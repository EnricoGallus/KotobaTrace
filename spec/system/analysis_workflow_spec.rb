require "rails_helper"
require "socket"
require "selenium/webdriver"

Selenium::WebDriver.logger.level = :warn

RSpec.describe "Analysis workflow", type: :system do
  include ActiveJob::TestHelper

  before do
    if ENV["SELENIUM_HOST"].present?
      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = ENV.fetch("CAPYBARA_SERVER_PORT", "45678").to_i
      Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}:#{Capybara.server_port}"
      driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ],
        options: { browser: :remote, url: "http://#{ENV.fetch('SELENIUM_HOST')}:4444/wd/hub" }
    else
      driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]
    end

    clear_enqueued_jobs
    allow(Flashcards::VocabularyLookup).to receive(:call).and_return(
      Flashcards::VocabularyCollection.new(unavailable: true)
    )
  end

  def open_analysis(locale = "en")
    visit new_analysis_path(locale: locale)
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
  end

  def submit_text(text, label = "Analyze")
    fill_in "text", with: text
    click_button label
    expect(page).to have_css('form[aria-busy="true"] fieldset[disabled]')
    expect(page).to have_css('[data-analyze-text-target="progress"]', visible: true)
  end

  it "keeps progress active after enqueueing, then allows assessment and saving" do
    choice = AssessmentChoice.create!(key: "known", position: 4)
    open_analysis
    submit_text("猫を見た")

    perform_enqueued_jobs

    expect(page).to have_text("Flashcard lookup is unavailable")
    expect(page).to have_css("tbody tr", minimum: 1)
    expect(page).to have_button("Analyze", disabled: false)
    expect(page).to have_field("text", with: "猫を見た", disabled: false)
    expect(page).to have_no_css('[data-analyze-text-target="progress"]', visible: true)
    first("tbody select").select(choice.label)
    click_button "Save"

    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.text).to eq("猫を見た")
    expect(Analysis.last.word_assessments.where(assessment_choice: choice)).to exist
  end

  it "recovers from job failure using the same text and ignores stale results" do
    open_analysis
    submit_text("猫")
    failed_request_id = page.find('input[name="request_id"]', visible: :all).value
    allow(Japanese::MorphologicalAnalyzer).to receive(:call).and_raise(StandardError, "Private error")
    perform_enqueued_jobs

    expect(page).to have_text("Analysis could not be completed")
    expect(page).not_to have_text("Private error")
    expect(page).to have_field("text", with: "猫", disabled: false)
    allow(Japanese::MorphologicalAnalyzer).to receive(:call).and_call_original
    click_button "Retry analysis"
    expect(page).to have_css('form[aria-busy="true"] fieldset[disabled]')

    Turbo::StreamsChannel.broadcast_update_to(
      page.find('input[name="stream_key"]', visible: :all).value,
      target: "analysis_results", partial: "analyses/error",
      locals: { message: "failed", request_id: failed_request_id }
    )
    perform_enqueued_jobs

    expect(page).to have_css("tbody tr", minimum: 1)
    expect(page).to have_button("Analyze", disabled: false)
    expect(page).not_to have_text("Analysis could not be completed")
  end

  it "keeps fast job results when completion arrives before the enqueue response" do
    allow(AnalyzeTextJob).to receive(:perform_later) do |*arguments|
      AnalyzeTextJob.perform_now(*arguments)
      AnalyzeTextJob.new
    end
    open_analysis
    fill_in "text", with: "猫"
    click_button "Analyze"

    expect(page).to have_css("tbody tr", minimum: 1)
    expect(page).to have_button("Analyze", disabled: false)
    expect(page).to have_no_css('form[aria-busy="true"]')
  end

  it "quietly skips flashcard enrichment when it is disabled" do
    allow(Flashcards::VocabularyLookup).to receive(:call).and_return(Flashcards::VocabularyCollection.new)
    open_analysis
    submit_text("猫")
    perform_enqueued_jobs

    expect(page).to have_css("tbody tr", minimum: 1)
    expect(page).not_to have_text("Flashcard lookup is unavailable")
  end

  it "shows useful empty results and restores Japanese controls" do
    open_analysis("ja")
    submit_text("。", "解析")
    perform_enqueued_jobs

    expect(page).to have_text("学習対象の語彙が見つかりませんでした")
    expect(page).to have_button("解析", disabled: false)
    expect(page).not_to have_button("保存")
    expect(page).not_to have_css("table")
  end

  it "rejects whitespace without leaving the form busy" do
    open_analysis
    fill_in "text", with: "　 \n "
    click_button "Analyze"

    expect(page).to have_text("Enter some Japanese text")
    expect(page).to have_button("Analyze", disabled: false)
    expect(page).to have_field("text", disabled: false)
    expect(enqueued_jobs).to be_empty
  end
end

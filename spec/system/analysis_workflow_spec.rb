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
    # Turbo releases the submit button after the enqueue response, while our
    # fieldset stays disabled until the background job completes.
    expect(page).to have_css('form[aria-busy="true"] input[type="submit"]:not([disabled])')
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

  it "bulk assesses only unselected words and saves the resulting choices" do
    known = AssessmentChoice.create!(key: "known", position: 4)
    unknown = AssessmentChoice.create!(key: "unknown", position: 1)
    open_analysis
    submit_text("猫と犬と鳥")
    perform_enqueued_jobs
    expect(page).to have_css("tbody select", count: 3)

    click_button "Apply"
    expect(all("tbody select").map(&:value)).to eq([ "", "", "" ])

    first("tbody select").select(unknown.label)
    select known.label, from: "Set unassessed words to"
    click_button "Apply"
    expect(all("tbody select").map(&:value)).to eq([ unknown.id.to_s, known.id.to_s, known.id.to_s ])

    # A second bulk action preserves all selections made by the first one.
    select unknown.label, from: "Set unassessed words to"
    click_button "Apply"
    expect(all("tbody select").map(&:value)).to eq([ unknown.id.to_s, known.id.to_s, known.id.to_s ])
    expect(Analysis.count).to eq(0)

    click_button "Save"
    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.word_assessments.where(assessment_choice: known).count).to eq(2)
    expect(Analysis.last.word_assessments.where(assessment_choice: unknown).count).to eq(1)
  end

  it "counts each saved passage once and opens history without losing draft selections" do
    known = AssessmentChoice.create!(key: "known", position: 4)
    unknown = AssessmentChoice.create!(key: "unknown", position: 1)
    word = Word.create!(lemma: "猫", part_of_speech: "名詞")
    [ [ "猫。猫。猫。", unknown ], [ "猫がいた。", known ] ].each do |text, choice|
      Analysis.create!(text: text).word_assessments.create!(word: word, assessment_choice: choice)
    end
    open_analysis
    submit_text("猫。猫。猫。犬。")
    perform_enqueued_jobs
    expect(page).to have_css("#analysis_results tbody tr", count: 2)
    cat_row = find("#analysis_results tbody tr", text: "猫")
    expect(cat_row.find("[data-passage-count]").text).to eq("2")
    cat_row.find("select").select(unknown.label)
    original_url = page.current_url
    cat_row.click_button "猫"

    within("dialog[open]") do
      expect(page).to have_css("[data-history-passage-count]", text: "2")
      expect(page).to have_text("First encounter")
      expect(page).to have_text("Last encounter")
      expect(page).to have_css(".assessment-totals li", text: /Don't know yet:\s*1/)
      expect(page).to have_css(".assessment-totals li", text: /Know both:\s*1/)
      expect(page).to have_text("Flashcard lookup is unavailable")
      expect(page).to have_css("[data-history-entry]", count: 2)
      click_button "Close"
    end
    expect(page.current_url).to eq(original_url)
    expect(cat_row.find("select").value).to eq(unknown.id.to_s)
    expect(page).to have_field("text", with: "猫。猫。猫。犬。")
    expect(Analysis.count).to eq(2)

    find("#analysis_results tbody tr", text: "犬").click_button "犬"
    within("dialog[open]") do
      expect(page).to have_text("This word has no saved history yet")
      page.driver.browser.action.send_keys(:escape).perform
    end
    expect(page).to have_no_css("dialog[open]")
    expect(cat_row.find("select").value).to eq(unknown.id.to_s)

    click_button "Save"
    expect(page).to have_text("Your analysis results will appear here")
    expect(word.reload.analyses.count).to eq(3)
    submit_text("猫")
    perform_enqueued_jobs
    expect(find("#analysis_results tbody tr [data-passage-count]").text).to eq("3")
    click_button "猫"
    within("dialog[open]") do
      expect(page).to have_css("[data-history-passage-count]", text: "3")
      expect(page).to have_css(".assessment-totals li", text: /Don't know yet:\s*2/)
    end
  end

  [ [ 1280, 900 ], [ 390, 844 ] ].each do |width, height|
    it "keeps the workspace stable and the history dialog usable at #{width}px" do
      page.driver.browser.manage.window.resize_to(width, height)
      known = AssessmentChoice.create!(key: "known", position: 4)
      word = Word.create!(lemma: "猫", part_of_speech: "名詞")
      8.times { Analysis.create!(text: "猫がいる文章です。" * 12).word_assessments.create!(word: word, assessment_choice: known) }
      open_analysis
      initial_width = find('[data-analyze-text-target="form"]').native.rect.width
      expect(initial_width).to be > width * 0.8
      submit_text("猫と犬")
      perform_enqueued_jobs
      expect(page).to have_css("#analysis_results tbody tr", count: 2)
      expect(find('[data-analyze-text-target="form"]').native.rect.width).to be_within(1).of(initial_width)
      expect(find(".results-panel").native.rect.width).to be_within(1).of(initial_width)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      screenshot_dir = Rails.root.join("tmp", "design-review")
      FileUtils.mkdir_p(screenshot_dir)
      page.save_screenshot(screenshot_dir.join("workspace-#{width}.png"))
      find("#analysis_results tbody tr", text: "猫").find("select").select(known.label)
      click_button "猫"
      within("dialog[open]") do
        expect(page).to have_css("[data-history-entry]", count: 8)
        expect(page).to have_css('.ui-notice--warning[role="status"]')
        expect(page).to have_no_css('[role="alert"]')
      end
      expect(page.evaluate_script("document.querySelector('.history-dialog-body').scrollWidth <= document.querySelector('.history-dialog-body').clientWidth")).to be(true)
      expect(page.evaluate_script("document.querySelector('dialog').getBoundingClientRect().width <= window.innerWidth")).to be(true)
      page.save_screenshot(screenshot_dir.join("history-#{width}.png"))
      page.execute_script("document.querySelector('.history-dialog-body').scrollTop = 100000")
      expect(page.evaluate_script("document.querySelector('.history-dialog-header').getBoundingClientRect().top >= 0")).to be(true)
      within("dialog[open]") { click_button "Close" }
      expect(find("#analysis_results tbody tr", text: "猫").find("select").value).to eq(known.id.to_s)
    end
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
    expect(page.find('input[name="request_id"]', visible: :all).value).not_to eq(failed_request_id)
    expect(page).to have_css('form[aria-busy="true"] input[type="submit"]:not([disabled])')

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

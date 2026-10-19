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
    allow(Japanese::TextAnalyzer).to receive(:call) { |text| deterministic_analysis(text) }
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

  def deterministic_analysis(text)
    candidates = Japanese::VocabularyExtractor.call(Japanese::MorphologicalAnalyzer.call(text))
      .select { |candidate| candidate.kind == :vocabulary }
    groups = candidates.group_by { |candidate| [ candidate.base_form, candidate.part_of_speech ] }
    words = Word.where(lemma: groups.keys.map(&:first).uniq)
      .index_by { |word| [ word.lemma, word.part_of_speech ] }
    analysis = Analysis.new(text: text)

    groups.each do |(lemma, part_of_speech), word_candidates|
      word = words[[ lemma, part_of_speech ]] || Word.new(lemma: lemma, part_of_speech: part_of_speech)
      assessment = analysis.word_assessments.build(word: word)
      assessment.surfaces = word_candidates.map(&:surface).uniq
      assessment.surface_readings = word_candidates.map(&:reading).compact.uniq
    end

    analysis
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
    all("tbody select").each { |select| select.select(choice.label) }
    click_button "Save"

    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.text).to eq("猫を見た")
    expect(Analysis.last.word_assessments.where(assessment_choice: choice)).to exist
  end

  [ [ 1280, 900 ], [ 390, 844 ] ].each do |width, height|
    it "reviews both tabs and validates hidden assessments before saving at #{width}px" do
      page.driver.browser.manage.window.resize_to(width, height)
      vocabulary_choice = AssessmentChoice.create!(key: "known", position: 4)
      grammar_choice = GrammarAssessmentChoice.create!(key: "understood", position: 3)
      allow(Japanese::TextAnalyzer).to receive(:call) do |text|
        analysis = deterministic_analysis(text)
        analysis.grammar_assessments.build(
          pattern: "〜ている", meaning: "ongoing action",
          explanation: "Describes an action in progress.", example: "食べている"
        )
        analysis
      end
      open_analysis
      submit_text("食べている")
      perform_enqueued_jobs

      expect(page).to have_css('[role="tab"][aria-selected="true"]', text: /Vocabulary\s+1/)
      expect(page).to have_no_css("#grammar-panel", visible: true)
      find('#vocabulary-tab').send_keys(:arrow_right)
      expect(page).to have_css('[role="tab"][aria-selected="true"]', text: /Grammar\s+1/)
      expect(page).to have_text("ongoing action")
      expect(page).to have_no_css("#vocabulary-panel", visible: true)

      # Saving from Grammar must reveal the first missing vocabulary choice.
      click_button "Save"
      expect(page).to have_css('#vocabulary-tab[aria-selected="true"]')
      expect(page).to have_css("#vocabulary-panel select:focus")
      first("tbody select").select(vocabulary_choice.label)
      click_button "Save"
      expect(page).to have_css('#grammar-tab[aria-selected="true"]')
      expect(page).to have_css("#grammar-panel select:focus")
      select grammar_choice.label, from: "Grammar assessment"

      find('#grammar-tab').send_keys(:home)
      expect(first("tbody select").value).to eq(vocabulary_choice.id.to_s)
      find("#grammar-tab").click
      expect(find("#grammar-panel select").value).to eq(grammar_choice.id.to_s)
      expect(page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth")).to be(true)
      FileUtils.mkdir_p(Rails.root.join("tmp", "design-review"))
      page.save_screenshot(Rails.root.join("tmp", "design-review", "grammar-tab-#{width}.png"))
      click_button "Save"

      expect(page).to have_text("Your analysis results will appear here")
      expect(Analysis.last.word_assessments.sole.assessment_choice).to eq(vocabulary_choice)
      expect(Analysis.last.grammar_assessments.sole.grammar_assessment_choice).to eq(grammar_choice)
    end
  end

  it "opens the grammar tab directly for a grammar-only analysis in Japanese" do
    allow(Japanese::TextAnalyzer).to receive(:call) do |text|
      analysis = Analysis.new(text: text)
      analysis.grammar_assessments.build(
        pattern: "〜としても", meaning: "たとえ〜でも",
        explanation: "仮定の条件を表す。", example: "としても"
      )
      analysis
    end
    open_analysis("ja")
    submit_text("としても", "解析")
    perform_enqueued_jobs

    expect(page).to have_css('[role="tab"][aria-selected="true"]', text: /文法\s+1/)
    expect(page).to have_text("仮定の条件を表す。")
    expect(page).to have_no_css("#vocabulary-tab")
  end

  it "requires a choice for every word and skips ignored words on save" do
    known = AssessmentChoice.create!(key: "known", position: 4)
    ignore = AssessmentChoice.create!(key: "ignore", position: 0)
    open_analysis
    submit_text("猫と犬")
    perform_enqueued_jobs
    expect(page).to have_css("tbody select[required]", count: 2)

    cat_row = find("tbody tr", text: "猫")
    cat_row.find("select").select(known.label)
    click_button "Save"
    expect(page.evaluate_script("document.querySelector('.results-panel').checkValidity()")).to be(false)
    expect(Analysis.count).to eq(0)
    expect(WordAssessment.count).to eq(0)

    find("tbody tr", text: "犬").find("select").select(ignore.label)
    click_button "Save"
    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.words.pluck(:lemma)).to eq([ "猫" ])
    expect(Word.exists?(lemma: "犬")).to be(false)
  end

  it "groups the study list conservatively and saves complete vocabulary forms" do
    known = AssessmentChoice.create!(key: "known", position: 4)
    open_analysis
    text = [
      "採用", "残業代付く", "流行ってる", "気持ちの面", "流行りに乗れる",
      "精神的", "鼠に", "かじる", "対策", "専業主婦", "家庭", "節約", "工夫", "実践",
      "返却日", "意見交換", "間接的", "政治的"
    ].join("\n")
    submit_text(text)
    perform_enqueued_jobs

    expected_forms = %w[採用 残業代 付く 流行る 気持ち 面 流行り 乗る 精神的 鼠 かじる 対策 専業主婦 家庭 節約 工夫 実践 返却日 意見交換 間接的 政治的]
    expect(page).to have_css("tbody tr", count: expected_forms.length)
    expect(all("tbody tr td:nth-child(2) button").map { |cell| cell.text.strip }).to eq(expected_forms)
    expect(find("tbody tr", text: "流行ってる").find("td:nth-child(3)").text).to eq("ハヤッテル")
    expect(find("tbody tr", text: "政治的").find("td:nth-child(4)").text).to eq("形容動詞")

    select known.label, from: "Set unassessed words to"
    click_button "Apply"
    click_button "Save"
    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.text).to eq(text)
    expect(Analysis.last.words.pluck(:lemma)).to match_array(expected_forms)
    expect(Analysis.last.words.pluck(:dictionary_reading)).to all(be_nil)
  end

  it "preserves particles within reviewed expressions and saves their normalized forms" do
    known = AssessmentChoice.create!(key: "known", position: 4)
    open_analysis
    submit_text("問題に目を向けた。はるかに大きい。")
    perform_enqueued_jobs

    expected_forms = %w[問題 目を向ける はるかに 大きい]
    expect(page).to have_css("tbody tr", count: expected_forms.length)
    expect(all("tbody tr td:nth-child(2) button").map { |cell| cell.text.strip }).to eq(expected_forms)
    expression_row = find("tbody tr", text: "目を向けた")
    expect(expression_row.find("td:nth-child(3)").text).to eq("メヲムケタ")
    expect(expression_row.find("td:nth-child(4)").text).to eq("表現")
    expect(find("tbody tr", text: "はるかに").find("td:nth-child(3)").text).to eq("ハルカニ")

    select known.label, from: "Set unassessed words to"
    click_button "Apply"
    click_button "Save"
    expect(page).to have_text("Your analysis results will appear here")
    expect(Analysis.last.words.pluck(:lemma)).to match_array(expected_forms)
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

    find("#analysis_results tbody tr", text: "犬").find("select").select(known.label)
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

  it "restores the form when the completion broadcast is lost" do
    open_analysis
    page.execute_script("document.querySelector('[data-controller~=analyze-text]').setAttribute('data-analyze-text-timeout-value', '1000')")
    submit_text("猫")

    expect(page).to have_text("Retry analysis")
    expect(page).to have_field("text", with: "猫", disabled: false)
    expect(page).to have_button("Analyze", disabled: false)
    expect(page).to have_no_css('[data-analyze-text-target="progress"]', visible: true)
  end

  it "allows retrying when the stream subscription is disconnected" do
    open_analysis
    page.execute_script("document.querySelector('turbo-cable-stream-source').remove()")
    fill_in "text", with: "猫"
    click_button "Analyze"

    expect(page).to have_text("Retry analysis")
    expect(page).to have_field("text", with: "猫", disabled: false)
    expect(enqueued_jobs).to be_empty
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

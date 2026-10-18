require_relative "../../support/japanese_services"

RSpec.describe "Conservative Japanese vocabulary grouping" do
  def extract(text)
    Japanese::VocabularyExtractor.call(Japanese::MorphologicalAnalyzer.call(text))
  end

  {
    "精神的" => [ "精神的", "セイシンテキ", "形容動詞" ],
    "間接的" => [ "間接的", "カンセツテキ", "形容動詞" ],
    "政治的" => [ "政治的", "セイジテキ", "形容動詞" ],
    "残業代" => [ "残業代", "ザンギョウダイ", "名詞" ],
    "返却日" => [ "返却日", "ヘンキャクビ", "名詞" ],
    "医療費" => [ "医療費", "イリョウヒ", "名詞" ],
    "使用料" => [ "使用料", "シヨウリョウ", "名詞" ],
    "専業主婦" => [ "専業主婦", "センギョウシュフ", "名詞" ],
    "意見交換" => [ "意見交換", "イケンコウカン", "名詞" ],
    "意見交換する" => [ "意見交換する", "イケンコウカンスル", "動詞" ],
    "意見交換された" => [ "意見交換する", "イケンコウカンサレタ", "動詞" ],
    "ご意見交換" => [ "意見交換", "ゴイケンコウカン", "名詞" ],
    "専業主婦的" => [ "専業主婦的", "センギョウシュフテキ", "形容動詞" ],
    "流行ってる" => [ "流行る", "ハヤッテル", "動詞" ],
    "流行ってた" => [ "流行る", "ハヤッテタ", "動詞" ],
    "流行ってます" => [ "流行る", "ハヤッテマス", "動詞" ],
    "読んでる" => [ "読む", "ヨンデル", "動詞" ],
    "引き継いだ" => [ "引き継ぐ", "ヒキツイダ", "動詞" ]
  }.each do |text, (base_form, reading, pos)|
    it "extracts #{text} as one complete vocabulary occurrence" do
      candidates = extract(text)

      expect(candidates.length).to eq(1)
      expect(candidates.first).to have_attributes(surface: text, base_form: base_form, reading: reading, part_of_speech: pos)
      expect(candidates.first.morphemes.map(&:surface).join).to eq(text)
    end
  end

  it "prefers the longest supported compound without absorbing a following word" do
    stub_const("Japanese::VocabularyLexicon::COMPOUNDS", Japanese::VocabularyLexicon::COMPOUNDS.merge(
      "意見交換会" => { suru: false }
    ))

    expect(extract("意見交換会。家庭。").map(&:base_form)).to eq(%w[意見交換会 家庭])
  end

  it "keeps a noun compound separate from the following verb" do
    expect(extract("残業代付く").map(&:base_form)).to eq(%w[残業代 付く])
  end

  it "keeps nominal 流行り separate from verbal 流行る and normalizes the known potential" do
    candidates = extract("流行ってる。流行りに乗れる。")

    expect(candidates.map { |c| [ c.surface, c.base_form, c.part_of_speech ] }).to eq([
      [ "流行ってる", "流行る", "動詞" ],
      [ "流行り", "流行り", "名詞" ],
      [ "乗れる", "乗る", "動詞" ]
    ])
    # Contextual interpretation never rewrites the raw analyzer output.
    expect(candidates[1].morphemes.first.base_form).to eq("流行る")
    expect(candidates[1].morphemes.first.part_of_speech).to eq("動詞")
    expect(candidates[2].morphemes.first.base_form).to eq("乗れる")
  end

  it "does not reinterpret verbal 流行りたい as a noun" do
    expect(extract("流行りたい").first).to have_attributes(base_form: "流行る", part_of_speech: "動詞")
  end

  it "does not turn an emphatic verbal stem into a noun" do
    expect(extract("流行りはする").first).to have_attributes(base_form: "流行る", part_of_speech: "動詞")
  end

  it "does not mechanically strip れる from unrelated verbs" do
    expect(extract("切れる。入れる。").map(&:base_form)).to eq(%w[切れる 入れる])
  end

  {
    "専業\n主婦" => %w[専業 主婦],
    "意見 交換" => %w[意見 交換],
    "意見　交換" => %w[意見 交換],
    "意見。交換" => %w[意見 交換],
    "意見、交換" => %w[意見 交換],
    "採用\n家庭" => %w[採用 家庭],
    "採用家庭" => %w[採用 家庭],
    "意見交換家庭" => %w[意見交換 家庭],
    "意見交換\nする" => %w[意見交換 する],
    "気持ちの面" => %w[気持ち 面],
    "鼠に" => %w[鼠]
  }.each do |text, forms|
    it "respects the word boundaries in #{text.inspect}" do
      expect(extract(text).map(&:base_form)).to eq(forms)
    end
  end

  it "never joins suffixes and helper verbs across whitespace" do
    expect(extract("精神\n的").map(&:surface)).not_to include("精神的")
    expect(extract("流行っ\nてる").map(&:surface)).not_to include("流行ってる")
    expect(extract("お\n申し込み").map(&:surface)).not_to include("お申し込み")
    expect(extract("三\n日").map(&:surface)).not_to include("三日")
    expect(extract("十五分\n前").map(&:kind)).not_to include(:time_expression)
  end

  it "preserves existing number and relative-time classification" do
    candidates = extract("三日。十五分前。")
    expect(candidates.map { |c| [ c.surface, c.kind ] }).to eq([
      [ "三日", :number ], [ "十五分前", :time_expression ]
    ])
  end

  it "retains separate repeated compound occurrences and exact source spans" do
    text = "専業主婦と専業主婦"
    candidates = extract(text)

    expect(candidates.length).to eq(2)
    expect(candidates.map { |c| c.morphemes.first.start_offset }).to eq([ 0, 5 ])
    candidates.each do |candidate|
      expect(text[candidate.morphemes.first.start_offset...candidate.morphemes.last.end_offset]).to eq(candidate.surface)
    end
  end

  it "filters punctuation even when the tokenizer assigns a noun POS" do
    parts = Japanese::MorphologicalAnalyzer.call("猫")
    punctuation = parts.first.with(surface: ",,", base_form: ",,", reading: nil, unknown: true)
    expect(Japanese::VocabularyExtractor.call([ punctuation ])).to be_empty
    expect(extract(",,名詞").map(&:base_form)).to eq([ "名詞" ])
  end
end

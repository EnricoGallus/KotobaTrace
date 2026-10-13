require "spec_helper"
require_relative "../../../app/services/japanese/morpheme"
require_relative "../../../app/services/japanese/vocabulary_candidate"
require_relative "../../../app/services/japanese/vocabulary_match"
Dir[File.expand_path("../../../app/services/japanese/vocabulary_rules/*.rb", __dir__)].sort.each { |path| require path }
require_relative "../../../app/services/japanese/vocabulary_extractor"

RSpec.describe Japanese::VocabularyExtractor do
  def morpheme(surface, base_form: surface, reading: nil, pos: "名詞", subtype1: nil, subtype2: nil)
    Japanese::Morpheme.new(
      surface: surface, base_form: base_form, reading: reading, part_of_speech: pos,
      pos_subtype1: subtype1, pos_subtype2: subtype2, pos_subtype3: nil,
      conjugation_type: nil, conjugation_form: nil, position: 0
    )
  end

  it "returns no candidates for empty input" do
    expect(described_class.call([])).to eq([])
  end

  it "combines honorific nouns while preserving their lookup form and source" do
    parts = [ morpheme("お", pos: "接頭詞", reading: "オ"), morpheme("申し込み", reading: "モウシコミ") ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("お申し込み")
    expect(candidate.base_form).to eq("申し込み")
    expect(candidate.reading).to eq("オモウシコミ")
    expect(candidate.kind).to eq(:vocabulary)
    expect(candidate.morphemes).to eq(parts)
  end

  it "classifies names with honorifics before the content word fallback" do
    parts = [ morpheme("田中", subtype1: "固有名詞"), morpheme("様") ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("田中様")
    expect(candidate.base_form).to eq("田中")
    expect(candidate.kind).to eq(:name)
  end

  it "combines multiple digits with a counter" do
    parts = [ morpheme("三", subtype1: "数"), morpheme("十", subtype1: "数"), morpheme("分", subtype2: "助数詞") ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("三十分")
    expect(candidate.base_form).to eq("三十分")
    expect(candidate.kind).to eq(:number)
  end

  it "combines passive helpers and auxiliaries" do
    parts = [
      morpheme("記載さ", base_form: "記載する", pos: "動詞", reading: "キサイサ"),
      morpheme("れ", base_form: "れる", pos: "動詞", reading: "レ"),
      morpheme("た", pos: "助動詞", reading: "タ")
    ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("記載された")
    expect(candidate.base_form).to eq("記載する")
    expect(candidate.reading).to eq("キサイサレタ")
    expect(candidate.morphemes).to eq(parts)
  end

  it "retains the existing split suru noun behavior including passive endings" do
    parts = [
      morpheme("記載", subtype1: "サ変接続"),
      morpheme("さ", base_form: "する", pos: "動詞"),
      morpheme("れ", base_form: "れる", pos: "動詞"),
      morpheme("た", pos: "助動詞")
    ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("記載された")
    expect(candidate.base_form).to eq("記載する")
    expect(candidate.part_of_speech).to eq("動詞")
  end

  it "combines te helpers and their endings without consuming the next word" do
    parts = [
      morpheme("持っ", base_form: "持つ", pos: "動詞"),
      morpheme("て", pos: "助詞", subtype1: "接続助詞"),
      morpheme("いき", base_form: "いく", pos: "動詞"),
      morpheme("ます", pos: "助動詞"), morpheme("本")
    ]
    candidates = described_class.call(parts)
    expect(candidates.map(&:surface)).to eq(%w[持っていきます 本])
    expect(candidates.first.base_form).to eq("持つ")
  end

  it "does not group unrelated verbs across a te connector" do
    parts = [
      morpheme("読ん", base_form: "読む", pos: "動詞"),
      morpheme("で", pos: "助詞", subtype1: "接続助詞"),
      morpheme("帰る", pos: "動詞")
    ]
    expect(described_class.call(parts).map(&:base_form)).to eq(%w[読む 帰る])
  end

  it "omits standalone function words, names, numbers and non-independent nouns" do
    parts = [
      morpheme("は", pos: "助詞"), morpheme("。", pos: "記号"),
      morpheme("ます", pos: "助動詞"), morpheme("お", pos: "接頭詞"),
      morpheme("三", subtype1: "数"), morpheme("田中", subtype1: "固有名詞"),
      morpheme("こと", subtype1: "非自立"), morpheme("本"),
      morpheme("美しい", pos: "形容詞"), morpheme("ゆっくり", pos: "副詞")
    ]
    expect(described_class.call(parts).map(&:surface)).to eq(%w[本 美しい ゆっくり])
  end

  it "returns no partial reading when any source reading is missing" do
    parts = [ morpheme("お", pos: "接頭詞"), morpheme("申し込み", reading: "モウシコミ") ]
    expect(described_class.call(parts).fetch(0).reading).to be_nil
  end

  it "reads every morpheme in 持っていく" do
    parts = [
      morpheme("持っ", base_form: "持つ", pos: "動詞", reading: "モッ"),
      morpheme("て", pos: "助詞", subtype1: "接続助詞", reading: "テ"),
      morpheme("いく", pos: "動詞", reading: "イク")
    ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("持っていく")
    expect(candidate.reading).to eq("モッテイク")
    expect(candidate.morphemes).to eq(parts)
  end

  it "preserves the honorific prefix and full reading of a request" do
    parts = [
      morpheme("お", pos: "接頭詞", reading: "オ"),
      morpheme("済ませ", base_form: "済ませる", pos: "動詞", reading: "スマセ"),
      morpheme("ください", base_form: "くださる", pos: "動詞", reading: "クダサイ")
    ]
    candidate = described_class.call(parts).fetch(0)
    expect(candidate.surface).to eq("お済ませください")
    expect(candidate.base_form).to eq("済ませる")
    expect(candidate.reading).to eq("オスマセクダサイ")
    expect(candidate.morphemes).to eq(parts)
  end

  it "does not treat every prefixed verb as an honorific request" do
    parts = [ morpheme("お", pos: "接頭詞"), morpheme("帰り", base_form: "帰る", pos: "動詞") ]
    expect(Japanese::VocabularyRules::HonorificVerb.call(parts, 0)).to be_nil
  end

  [ %w[十 五 分 前], %w[二 時間 後], %w[二 時 間 後] ].each do |surfaces|
    it "groups #{surfaces.join} before the number-counter rule" do
      parts = surfaces.map do |surface|
        morpheme(surface, subtype1: %w[十 五 二].include?(surface) ? "数" : nil)
      end
      candidates = described_class.call(parts + [ morpheme("受付") ])
      expect(candidates.map(&:surface)).to eq([ surfaces.join, "受付" ])
      expect(candidates.first.kind).to eq(:time_expression)
      expect(candidates.first.morphemes).to eq(parts)
    end
  end

  it "leaves 前 as vocabulary outside a numeric time expression" do
    parts = [ morpheme("三", subtype1: "数"), morpheme("人"), morpheme("前") ]
    expect(described_class.call(parts).map(&:surface)).to eq(%w[三人 前])
    expect(described_class.call([ morpheme("前") ]).first.kind).to eq(:vocabulary)
  end

  it "preserves repeated occurrences with distinct source positions" do
    first = morpheme("受付").with(position: 0)
    second = morpheme("受付").with(position: 2)
    parts = [ first, morpheme("と", pos: "助詞").with(position: 1), second ]
    candidates = described_class.call(parts)
    expect(candidates.map(&:surface)).to eq(%w[受付 受付])
    expect(candidates.map { |candidate| candidate.morphemes.first.position }).to eq([ 0, 2 ])
  end
end

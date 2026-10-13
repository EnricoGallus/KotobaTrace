require_relative "../../support/japanese_services"

RSpec.describe "Japanese vocabulary pipeline" do
  it "extracts grouped vocabulary from real MeCab output" do
    morphemes = Japanese::MorphologicalAnalyzer.call("田中様のお申し込みは記載された。三十分、本を持っていく。")
    candidates = Japanese::VocabularyExtractor.call(morphemes)

    expect(candidates.map { |candidate| [ candidate.surface, candidate.base_form, candidate.kind ] }).to include(
      [ "田中様", "田中", :name ],
      [ "お申し込み", "申し込み", :vocabulary ],
      [ "記載された", "記載する", :vocabulary ],
      [ "三十分", "三十分", :number ],
      [ "持っていく", "持つ", :vocabulary ]
    )
    expect(morphemes.map(&:surface)).to include("は", "。")
    expect(candidates.find { |candidate| candidate.surface == "記載された" }.reading).to eq("キサイサレタ")
    expect(candidates.find { |candidate| candidate.surface == "持っていく" }.reading).to eq("モッテイク")
  end

  it "recognizes honorific requests and relative times in a real sentence" do
    morphemes = Japanese::MorphologicalAnalyzer.call("開始十五分前までにお済ませください。二時間後。")
    candidates = Japanese::VocabularyExtractor.call(morphemes)
    request = candidates.find { |candidate| candidate.surface == "お済ませください" }
    expect(request.base_form).to eq("済ませる")
    expect(request.reading).to eq("オスマセクダサイ")
    expect(candidates.select { |candidate| candidate.kind == :time_expression }.map(&:surface)).to eq(%w[十五分前 二時間後])
  end
end

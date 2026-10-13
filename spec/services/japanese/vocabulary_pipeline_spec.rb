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
  end
end

require "rails_helper"

RSpec.describe Japanese::Tokenizer do
  describe "realistic Japanese sentences" do
    examples = [
      {
        text: "政府は対応を促した。",
        expected_base_forms: %w[政府 対応 促す]
      },
      {
        text: "物価の上昇は著しかった。",
        expected_base_forms: %w[物価 上昇 著しい]
      },
      {
        text: "この本を読まなければならない。",
        expected_base_forms: %w[本 読む]
      },
      {
        text: "新しい制度が多くの人に受け入れられた。",
        expected_base_forms: %w[新しい 制度 人 受け入れる]
      },
      {
        text: "子どものころ、毎日野菜を食べさせられた。",
        expected_base_forms: %w[子ども 毎日 野菜 食べる]
      },
      {
        text: "人口が徐々に減っている。",
        expected_base_forms: %w[人口 徐々に 減る]
      },
      {
        text: "財布を電車に忘れてしまった。",
        expected_base_forms: %w[財布 電車 忘れる]
      },
      {
        text: "会議の前に資料を読んでおいた。",
        expected_base_forms: %w[会議 前 資料 読む]
      },
      {
        text: "彼は何も言わずに帰った。",
        expected_base_forms: %w[彼 言う 帰る]
      },
      {
        text: "明日は早く帰ります。",
        expected_base_forms: %w[明日 早い 帰る]
      },
      {
        text: "試験はそれほど難しくなかった。",
        expected_base_forms: %w[試験 難しい]
      },
      {
        text: "高齢化に伴って医療費が増えている。",
        expected_base_forms: %w[伴う 医療 費 増える]
      },
      {
        text: "計画を変更せざるを得ない。",
        expected_base_forms: %w[計画 変更 する]
      },
      {
        text: "全員が賛成しているわけではない。",
        expected_base_forms: %w[全員 賛成 する]
      },
      {
        text: "劣等感を抱く必要はない。",
        expected_base_forms: %w[抱く 必要]
      },
      {
        text: "社会保障制度について学んだ。",
        expected_base_forms: %w[制度 学ぶ]
      },
      {
        text: "若者の海外旅行離れが話題になっている。",
        expected_base_forms: %w[若者 話題 なる]
      },
      {
        text: "日本では少子高齢化が進んでいる。",
        expected_base_forms: %w[日本 進む]
      },
      {
        text: "先生がおっしゃったことを今でも覚えている。",
        expected_base_forms: %w[先生 おっしゃる 覚える]
      }
    ]

    examples.each_with_index do |example, index|
      it "extracts useful base forms from example #{index + 1}: #{example[:text]}" do
        tokens = described_class.call(example[:text])
        base_forms = tokens.map(&:base_form)

        aggregate_failures do
          example[:expected_base_forms].each do |expected|
            expect(base_forms).to include(expected)
          end
        end
      end
    end
  end

  describe "known analyzer limitations" do
    # Linguistically this should resolve to 降る.
    # NAIST-jdic currently resolves the ambiguous stem 降り to 降りる.
    # Keep this test as characterization of the analyzer, not desired behavior.
    it "currently misidentifies 降り in 雨が降りそう as 降りる" do
      tokens = described_class.call("雨が降りそうなので、傘を持っていく。")

      token = tokens.find { |t| t.surface == "降り" }

      expect(token.base_form).to eq("降りる")
    end
  end
end

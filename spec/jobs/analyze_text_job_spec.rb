require 'rails_helper'

RSpec.describe AnalyzeTextJob, type: :job do
  describe "#perform" do
    it "builds an unsaved analysis with associated words and broadcasts it" do
      token = Japanese::Tokenizer::Token.new(
        surface: "猫",
        base_form: "猫",
        reading: "ネコ",
        part_of_speech: "名詞"
      )
      index = instance_double(Anki::VocabularyIndex)
      existing_word = Word.create!(lemma: "猫", part_of_speech: "名詞", dictionary_reading: "ネコ")
      broadcast_locals = nil

      allow(Japanese::Tokenizer).to receive(:call).with("猫").and_return([ token ])
      allow(Anki::VocabularyIndex).to receive(:new).and_return(index)
      allow(index).to receive(:scan).and_return(index)
      allow(index).to receive(:include?).with("猫").and_return(true)

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to) do |stream, target:, partial:, locals:|
        expect(stream).to eq("stream-123")
        expect(target).to eq("analysis_results")
        expect(partial).to eq("analyses/results")
        broadcast_locals = locals
        expect(I18n.locale).to eq(:ja)
      end

      described_class.perform_now("猫", "stream-123", "ja")

      analysis = broadcast_locals.fetch(:analysis)
      expect(analysis).not_to be_persisted
      expect(analysis.text).to eq("猫")
      expect(analysis.word_assessments.size).to eq(1)
      expect(analysis.word_assessments.first.word).to eq(existing_word)
      expect(analysis.word_assessments.first.surfaces).to eq([ "猫" ])
      expect(analysis.word_assessments.first.in_anki).to be(true)
    end
  end
end

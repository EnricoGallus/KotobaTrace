require 'rails_helper'

RSpec.describe AnalyzeTextJob, type: :job do
  describe "#perform" do
    it "builds an unsaved analysis with associated words and broadcasts it" do
      candidate = Japanese::VocabularyCandidate.new(
        surface: "猫",
        base_form: "猫",
        reading: "ネコ",
        part_of_speech: "名詞",
        kind: :vocabulary,
        morphemes: []
      )
      collection = Flashcards::VocabularyCollection.new([ "猫" ], checked: true)
      existing_word = Word.create!(lemma: "猫", part_of_speech: "名詞", dictionary_reading: "ネ")
      broadcast_locals = nil

      morphemes = []
      allow(Japanese::MorphologicalAnalyzer).to receive(:call).with("猫").and_return(morphemes)
      allow(Japanese::VocabularyExtractor).to receive(:call).with(morphemes).and_return([
        candidate,
        candidate.with(surface: "田中様", base_form: "田中", kind: :name),
        candidate.with(surface: "三十分", base_form: "三十分", kind: :number),
        candidate.with(surface: "十五分前", base_form: "十五分前", kind: :time_expression)
      ])
      allow(Flashcards::VocabularyLookup).to receive(:call).and_return(collection)

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
      expect(analysis.word_assessments.first.surface_readings).to eq([ "ネコ" ])
      expect(existing_word.reload.dictionary_reading).to eq("ネ")
      expect(analysis.word_assessments.first.in_flashcards).to be(true)
    end

    it "still broadcasts usable results and allows saving when Anki is unavailable" do
      allow(AnkiConnect::Client).to receive(:new).and_raise(
        AnkiConnect::TransportError.new("Connection refused", original_error: Errno::ECONNREFUSED.new)
      )
      allow(Flashcards::VocabularyLookup).to receive(:call).and_wrap_original do |lookup|
        lookup.call(provider: "anki", deck: "Vocabulary", expression_field: "Expression")
      end
      analysis = nil
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to) do |_, **options|
        analysis = options.fetch(:locals).fetch(:analysis)
      end

      expect { described_class.perform_now("猫を見た", "stream-123") }.not_to raise_error

      expect(analysis.word_assessments).not_to be_empty
      expect(analysis.word_assessments.map(&:in_flashcards)).to all(be_nil)
      analysis.save!
      expect(analysis.reload.words.pluck(:lemma)).to include("猫")
    end
  end
end

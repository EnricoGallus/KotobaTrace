require 'rails_helper'

RSpec.describe AnalyzeTextJob, type: :job do
  describe "#perform" do
    it "delegates analysis and broadcasts the unsaved analysis with flashcard membership" do
      existing_word = Word.create!(lemma: "猫", part_of_speech: "名詞", dictionary_reading: "ネ")
      analysis = Analysis.new(text: "猫")
      assessment = analysis.word_assessments.build(word: existing_word)
      assessment.surfaces = [ "猫" ]
      assessment.surface_readings = [ "ネコ" ]
      analysis.grammar_assessments.build(
        pattern: "〜ている", meaning: "ongoing action", explanation: "Describes an action in progress.",
        example: "食べている"
      )
      collection = Flashcards::VocabularyCollection.new([ "猫" ], checked: true)
      broadcast_locals = nil

      allow(Japanese::TextAnalyzer).to receive(:call).with("猫").and_return(analysis)
      allow(Flashcards::VocabularyLookup).to receive(:call).and_return(collection)

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to) do |stream, target:, partial:, locals:|
        expect(stream).to eq("stream-123")
        expect(target).to eq("analysis_results")
        expect(partial).to eq("analyses/results")
        broadcast_locals = locals
        expect(I18n.locale).to eq(:ja)
      end

      described_class.perform_now("猫", "stream-123", "ja")

      expect(broadcast_locals.fetch(:analysis)).to equal(analysis)
      expect(analysis).not_to be_persisted
      expect(assessment.in_flashcards).to be(true)
      expect(analysis.grammar_assessments.size).to eq(1)
      expect(existing_word.reload.dictionary_reading).to eq("ネ")
    end

    it "still broadcasts usable results and allows saving when Anki is unavailable" do
      analysis = analysis_with_vocabulary
      allow(Japanese::TextAnalyzer).to receive(:call).and_return(analysis)
      allow(AnkiConnect::Client).to receive(:new).and_raise(
        AnkiConnect::TransportError.new("Connection refused", original_error: Errno::ECONNREFUSED.new)
      )
      allow(Flashcards::VocabularyLookup).to receive(:call).and_wrap_original do |lookup|
        lookup.call(provider: "anki", deck: "Vocabulary", expression_field: "Expression")
      end
      broadcast_analysis = nil
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to) do |_, **options|
        broadcast_analysis = options.fetch(:locals).fetch(:analysis)
        expect(options[:locals][:flashcards_unavailable]).to be(true)
      end

      expect { described_class.perform_now("猫", "stream-123") }.not_to raise_error

      expect(broadcast_analysis.word_assessments).not_to be_empty
      expect(broadcast_analysis.word_assessments.map(&:in_flashcards)).to all(be_nil)
      choice = AssessmentChoice.create!(key: "known", position: 4)
      broadcast_analysis.word_assessments.each { |assessment| assessment.assessment_choice = choice }
      broadcast_analysis.save!
      expect(broadcast_analysis.reload.words.pluck(:lemma)).to include("猫")
    end

    it "broadcasts a localized retryable failure with the request ID" do
      allow(Japanese::TextAnalyzer).to receive(:call).and_raise(StandardError, "Internal details")

      expect(Rails.logger).to receive(:error).with(a_string_including("request_id=attempt-1", "StandardError", "Internal details"))

      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to).with(
        "stream-123", target: "analysis_results", partial: "analyses/error",
        locals: { message: "failed", request_id: "attempt-1" }
      ) { expect(I18n.locale).to eq(:ja) }

      described_class.perform_now("猫", "stream-123", "ja", "attempt-1")
    end

    it "broadcasts an empty result with completion metadata" do
      allow(Japanese::TextAnalyzer).to receive(:call).and_return(Analysis.new(text: "。"))
      allow(Flashcards::VocabularyLookup).to receive(:call).and_return(Flashcards::VocabularyCollection.new)
      expect(Turbo::StreamsChannel).to receive(:broadcast_update_to) do |_, **options|
        expect(options[:partial]).to eq("analyses/results")
        expect(options[:locals][:analysis].word_assessments).to be_empty
        expect(options[:locals][:analysis].grammar_assessments).to be_empty
        expect(options[:locals][:request_id]).to eq("attempt-1")
        expect(options[:locals][:flashcards_unavailable]).to be(false)
      end

      described_class.perform_now("。", "stream-123", "en", "attempt-1")
    end
  end

  def analysis_with_vocabulary
    word = Word.new(lemma: "猫", part_of_speech: "名詞")
    analysis = Analysis.new(text: "猫")
    assessment = analysis.word_assessments.build(word: word)
    assessment.surfaces = [ "猫" ]
    assessment.surface_readings = [ "ネコ" ]
    analysis
  end
end

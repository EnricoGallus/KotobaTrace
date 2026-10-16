class WordHistoriesController < ApplicationController
  def show
    @word = Word.find_or_initialize_by(
      lemma: params.require(:lemma),
      part_of_speech: params.require(:part_of_speech)
    )
    @history = @word.word_assessments.includes(:analysis, :assessment_choice)
      .joins(:analysis).order("analyses.created_at DESC", "word_assessments.id DESC").to_a
    @choice_counts = @history.group_by { |assessment| assessment.assessment_choice&.key }
      .transform_values(&:size)
    @flashcards = Flashcards::VocabularyLookup.call
  end
end

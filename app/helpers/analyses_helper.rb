module AnalysesHelper
  def saved_passage_counts(analysis)
    Word.saved_passage_counts(analysis.word_assessments.map { |assessment| assessment.word&.id })
  end
end

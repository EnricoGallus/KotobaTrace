class ReplaceChoiceWithAssessmentChoice < ActiveRecord::Migration[8.1]
  def change
    add_reference :word_assessments, :assessment_choice, foreign_key: true
    remove_column :word_assessments, :choice, :string
  end
end

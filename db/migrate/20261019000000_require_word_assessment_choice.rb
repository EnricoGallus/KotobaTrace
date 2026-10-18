class RequireWordAssessmentChoice < ActiveRecord::Migration[8.1]
  def up
    # Ignore means no saved encounter. Blank choices are invalid assessments.
    # Preserve the associated words, analyses, and all other assessment history.
    execute <<~SQL
      DELETE FROM word_assessments
      WHERE assessment_choice_id IS NULL
         OR assessment_choice_id IN (SELECT id FROM assessment_choices WHERE key = 'ignore')
    SQL

    change_column_null :word_assessments, :assessment_choice_id, false
  end

  def down
    change_column_null :word_assessments, :assessment_choice_id, true
  end
end

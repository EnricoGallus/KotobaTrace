class CreateGrammarAssessmentChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :grammar_assessment_choices do |t|
      t.string :key, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :grammar_assessment_choices, :key, unique: true

    remove_reference :grammar_assessments, :assessment_choice, foreign_key: true
    add_reference :grammar_assessments, :grammar_assessment_choice, null: false, foreign_key: true
  end
end

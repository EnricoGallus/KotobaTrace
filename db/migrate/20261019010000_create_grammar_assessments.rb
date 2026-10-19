class CreateGrammarAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :grammar_assessments do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :assessment_choice, null: false, foreign_key: true
      t.string :pattern, null: false
      t.text :meaning, null: false
      t.text :explanation, null: false
      t.text :example, null: false
      t.datetime :assessed_at

      t.timestamps
    end

    add_index :grammar_assessments, [ :analysis_id, :pattern ], unique: true
  end
end

class CreateWordAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :word_assessments do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true
      t.string :choice
      t.datetime :assessed_at

      t.timestamps
    end

    add_index :word_assessments, [ :analysis_id, :word_id ], unique: true
  end
end

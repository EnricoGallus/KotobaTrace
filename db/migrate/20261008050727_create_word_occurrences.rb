class CreateWordOccurrences < ActiveRecord::Migration[8.1]
  def change
    create_table :word_occurrences do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true
      t.integer :position
      t.string :surface
      t.string :surface_reading

      t.timestamps
    end

    add_index :word_occurrences, [ :analysis_id, :position ], unique: true
  end
end

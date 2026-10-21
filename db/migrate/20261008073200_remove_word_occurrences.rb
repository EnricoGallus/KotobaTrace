class RemoveWordOccurrences < ActiveRecord::Migration[8.1]
  def change
    drop_table :word_occurrences do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true
      t.integer :position
      t.string :surface
      t.string :surface_reading

      t.timestamps

      t.index [ :analysis_id, :position ], unique: true
    end
  end
end

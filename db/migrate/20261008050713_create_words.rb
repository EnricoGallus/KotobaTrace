class CreateWords < ActiveRecord::Migration[8.1]
  def change
    create_table :words do |t|
      t.string :lemma
      t.string :part_of_speech
      t.string :dictionary_reading

      t.timestamps
    end

    add_index :words, [ :lemma, :part_of_speech ], unique: true
  end
end

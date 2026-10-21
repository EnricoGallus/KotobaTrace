class CreateAssessmentChoices < ActiveRecord::Migration[8.1]
  def change
    create_table :assessment_choices do |t|
      t.string :key
      t.string :label
      t.integer :position

      t.timestamps
    end
  end
end

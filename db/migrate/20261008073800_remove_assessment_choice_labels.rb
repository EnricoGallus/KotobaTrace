class RemoveAssessmentChoiceLabels < ActiveRecord::Migration[8.1]
  def up
    if select_value("SELECT EXISTS (SELECT 1 FROM assessment_choices)")
      raise ActiveRecord::IrreversibleMigration,
        "Translate existing assessment choices by key before removing their stored labels."
    end

    remove_column :assessment_choices, :label, :string
  end

  def down
    add_column :assessment_choices, :label, :string
  end
end

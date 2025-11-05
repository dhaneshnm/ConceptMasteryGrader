class CreateGradeReports < ActiveRecord::Migration[8.1]
  def change
    create_table :grade_reports do |t|
      t.references :conversation, null: false, foreign_key: true
      t.jsonb :scores
      t.text :feedback

      t.timestamps
    end
  end
end

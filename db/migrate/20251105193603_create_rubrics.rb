class CreateRubrics < ActiveRecord::Migration[8.1]
  def change
    create_table :rubrics do |t|
      t.references :course_material, null: false, foreign_key: true
      t.string :concept
      t.jsonb :levels

      t.timestamps
    end
  end
end

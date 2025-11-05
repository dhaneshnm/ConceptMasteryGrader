class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.references :student, null: false, foreign_key: true
      t.references :course_material, null: false, foreign_key: true

      t.timestamps
    end
  end
end

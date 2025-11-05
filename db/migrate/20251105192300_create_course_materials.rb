class CreateCourseMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :course_materials do |t|
      t.string :title, null: false
      t.integer :status, default: 0, null: false # enum: uploaded, processed

      t.timestamps
    end
    
    add_index :course_materials, :status
  end
end

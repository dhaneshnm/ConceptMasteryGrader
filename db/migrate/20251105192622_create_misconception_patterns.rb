class CreateMisconceptionPatterns < ActiveRecord::Migration[8.0]
  def change
    create_table :misconception_patterns do |t|
      t.references :course_material, null: false, foreign_key: true
      t.string :concept, null: false
      t.string :name, null: false
      # Store as JSONB arrays for better querying
      t.jsonb :signal_phrases, default: []
      t.jsonb :recommended_followups, default: []

      t.timestamps
    end
    
    add_index :misconception_patterns, :concept
    add_index :misconception_patterns, :signal_phrases, using: :gin
  end
end

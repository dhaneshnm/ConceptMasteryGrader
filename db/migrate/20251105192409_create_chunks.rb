class CreateChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :chunks do |t|
      t.references :course_material, null: false, foreign_key: true
      t.text :text, null: false
      # pgvector column for embeddings (1536 dimensions for OpenAI embeddings)
      t.column :embedding, "vector(1536)"

      t.timestamps
    end
    
    # Add index for efficient similarity search using hnsw
    add_index :chunks, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end

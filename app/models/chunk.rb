# Chunk represents a semantically meaningful segment of course material text.
# Each chunk contains an embedding vector for semantic similarity search in RAG operations.
class Chunk < ApplicationRecord
  belongs_to :course_material
  
  # Validations
  validates :text, presence: true, length: { minimum: 10 }
  validates :embedding, presence: true
  
  # Scope for similarity search using pgvector
  scope :similar_to, ->(query_embedding, limit: 5) {
    select("id, text, course_material_id, embedding <=> '#{query_embedding}' AS similarity")
      .order('similarity')
      .limit(limit)
  }
  
  # Convert embedding array to pgvector format
  def self.create_with_embedding(course_material:, text:, embedding_array:)
    # Convert array to pgvector format - wrap in brackets and join with commas
    embedding_string = "[#{embedding_array.join(',')}]"
    
    create!(
      course_material: course_material,
      text: text,
      embedding: embedding_string
    )
  end
  
  # Generate embedding for text using LLM
  def self.generate_embedding_for(text)
    LLM.embed(text)
  end
end

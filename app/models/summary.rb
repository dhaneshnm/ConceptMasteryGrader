# Summary represents an AI-generated structured summary of course material.
# Generated through RAG by retrieving and synthesizing the most relevant chunks.
class Summary < ApplicationRecord
  belongs_to :course_material
  
  # Validations
  validates :content, presence: true, length: { minimum: 50 }
  
  # Only one summary per course material
  validates :course_material_id, uniqueness: true
end

# Rubric represents assessment criteria for educational concepts.
# Generated through RAG analysis with levels: beginner, developing, proficient, mastery.
class Rubric < ApplicationRecord
  belongs_to :course_material
  
  # Validations
  validates :concept, presence: true, length: { minimum: 1, maximum: 255 }
  validates :levels, presence: true
  validate :levels_structure
  
  # Scope for concept-based queries
  scope :for_concept, ->(concept_name) { where(concept: concept_name) }
  
  # Expected levels structure in JSONB
  EXPECTED_LEVELS = %w[beginner developing proficient mastery].freeze
  
  # Get level description for a specific proficiency
  def level_description(level_name)
    levels[level_name.to_s]
  end
  
  # Check if student response matches a particular level
  def matches_level?(response_text, level_name)
    level_desc = level_description(level_name)
    return false unless level_desc
    
    # Simple keyword matching - can be enhanced with ML
    level_desc.downcase.split.any? { |word| response_text.downcase.include?(word) }
  end
  
  private
  
  def levels_structure
    return unless levels.present?
    
    missing_levels = EXPECTED_LEVELS - levels.keys
    if missing_levels.any?
      errors.add(:levels, "must include all levels: #{missing_levels.join(', ')}")
    end
  end
end

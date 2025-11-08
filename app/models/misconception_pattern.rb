# MisconceptionPattern identifies common student errors and provides remediation strategies.
# Used in the evaluator to detect misconceptions and suggest appropriate follow-up questions.
class MisconceptionPattern < ApplicationRecord
  belongs_to :course_material
  
  # Validations
  validates :concept, presence: true
  validates :name, presence: true
  validates :signal_phrases, presence: true
  validates :recommended_followups, presence: true
  
  # Scope for concept-based queries
  scope :for_concept, ->(concept_name) { where(concept: concept_name) }
  
  # Check if text contains signals for this misconception
  def detected_in?(text)
    normalized_text = text.downcase
    signal_phrases.any? { |phrase| normalized_text.include?(phrase.downcase) }
  end
  
  # Get a random follow-up question
  def random_followup
    recommended_followups.sample
  end
end

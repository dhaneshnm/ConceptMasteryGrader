# GradeReport represents the assessment results for a student's conversation.
# Contains scores mapped to rubric concepts and detailed feedback.
class GradeReport < ApplicationRecord
  belongs_to :conversation
  
  # Validations
  validates :conversation, presence: true
  validates :scores, presence: true
  validates :feedback, presence: true, length: { minimum: 10 }
  validate :scores_structure
  
  # Get score for a specific concept
  def score_for(concept)
    scores[concept.to_s]
  end
  
  # Get overall average score
  def average_score
    return 0 if scores.empty?
    
    total = scores.values.sum { |score| level_to_number(score) }
    (total.to_f / scores.size).round(2)
  end
  
  # Get performance level based on average
  def performance_level
    avg = average_score
    case avg
    when 0...1.5 then 'beginner'
    when 1.5...2.5 then 'developing'  
    when 2.5...3.5 then 'proficient'
    when 3.5..4.0 then 'mastery'
    else 'unassessed'
    end
  end
  
  # Get concepts that need improvement
  def concepts_needing_improvement
    scores.select { |_concept, level| level_to_number(level) < 2.5 }.keys
  end
  
  # Get strengths (concepts at proficient or mastery level)
  def strengths
    scores.select { |_concept, level| level_to_number(level) >= 2.5 }.keys
  end
  
  # Check if student needs attention based on performance
  def needs_attention?
    average_score < 2.0 || concepts_needing_improvement.size > (scores.size / 2)
  end
  
  # Generate JSON data for dashboard display
  def to_dashboard_json
    {
      id: id,
      conversation_id: conversation.id,
      student_name: conversation.student.name,
      course_material_title: conversation.course_material.title,
      average_score: average_score,
      performance_level: performance_level,
      evaluated_at: updated_at.iso8601,
      needs_attention: needs_attention?,
      concept_count: scores.keys.size,
      strengths: strengths,
      areas_for_improvement: concepts_needing_improvement
    }
  end
  
  private
  
  def level_to_number(level)
    case level.to_s.downcase
    when 'beginner' then 1
    when 'developing' then 2
    when 'proficient' then 3
    when 'mastery' then 4
    else 0
    end
  end
  
  def scores_structure
    return unless scores.present?
    
    invalid_scores = scores.values.reject do |score|
      %w[beginner developing proficient mastery].include?(score.to_s.downcase)
    end
    
    if invalid_scores.any?
      errors.add(:scores, "must use valid levels: beginner, developing, proficient, mastery")
    end
  end
end
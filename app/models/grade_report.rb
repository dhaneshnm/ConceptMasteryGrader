# GradeReport represents the assessment results for a student's conversation.
# Contains scores mapped to rubric concepts and detailed feedback.
class GradeReport < ApplicationRecord
  belongs_to :conversation
  
  # Callbacks
  before_save :calculate_overall_score
  
  # Validations
  validates :conversation, presence: true
  validates :scores, presence: true
  validates :feedback, presence: true, length: { minimum: 10 }
  validate :scores_structure
  
  # Get score for a specific concept
  def score_for(concept)
    scores[concept.to_s]
  end
  
  # Get overall average score (0-1 scale)
  def average_score
    overall_score || calculate_overall_score_value
  end
  
  # Get performance level based on average
  def performance_level
    avg = average_score
    case avg
    when 0...0.375 then 'beginner'      # 0-37.5% (was 0-1.5)
    when 0.375...0.625 then 'developing'  # 37.5-62.5% (was 1.5-2.5)
    when 0.625...0.875 then 'proficient'  # 62.5-87.5% (was 2.5-3.5)
    when 0.875..1.0 then 'mastery'      # 87.5-100% (was 3.5-4.0)
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
    average_score < 0.5 || concepts_needing_improvement.size > (scores.size / 2)
  end
  
  # Generate learning recommendations based on performance
  def recommendations
    recs = []
    
    # Recommendations based on weak concepts
    weak_concepts = concepts_needing_improvement
    if weak_concepts.any?
      weak_concepts.each do |concept|
        formatted_concept = concept.to_s.humanize
        recs << "Focus on improving #{formatted_concept} concepts through additional practice and review"
      end
    end
    
    # General recommendations based on overall performance
    case performance_level
    when 'beginner'
      recs << "Consider reviewing foundational concepts before advancing to new material"
      recs << "Schedule additional practice sessions to strengthen core understanding"
    when 'developing'
      recs << "Continue practicing to build confidence in key concepts"
      recs << "Focus on areas where understanding seems incomplete"
    when 'proficient'
      recs << "Great work! Consider exploring more advanced applications of these concepts"
    when 'mastery'
      recs << "Excellent understanding! Ready to move on to more challenging material"
    end
    
    # If more than half the concepts need work
    if weak_concepts.size > (scores.size / 2)
      recs << "Consider scheduling a one-on-one session to address multiple knowledge gaps"
    end
    
    recs
  end
  
  # Get detailed scores for each concept (formatted for UI display)
  def detailed_scores
    return {} if scores.blank?
    
    scores.transform_values do |level|
      {
        'level' => level,
        'score' => level_to_number(level) / 4.0 # Convert to 0-1 scale for progress bars
      }
    end
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
      evaluated_at: created_at.iso8601,
      needs_attention: needs_attention?,
      concept_count: scores.keys.size,
      strengths: strengths,
      areas_for_improvement: concepts_needing_improvement
    }
  end
  
  private
  
  def calculate_overall_score_value
    return 0 if scores.blank?
    
    total = scores.values.sum { |score| level_to_number(score) }
    (total.to_f / scores.size / 4.0).round(3) # Convert to 0-1 scale
  end
  
  def calculate_overall_score
    self.overall_score = calculate_overall_score_value
  end
  
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
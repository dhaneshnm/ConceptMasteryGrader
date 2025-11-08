# Helper methods for grade report display and formatting
module GradeReportsHelper
  
  # Convert numeric score to performance level description
  def performance_level(score)
    case score
    when 0.9..1.0
      "Outstanding"
    when 0.8..0.9
      "Excellent"  
    when 0.7..0.8
      "Proficient"
    when 0.6..0.7
      "Developing"
    when 0.5..0.6
      "Approaching"
    else
      "Needs Support"
    end
  end
  
  # Get CSS classes for performance level badges
  def level_badge_classes(level)
    base_classes = "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
    
    case level&.downcase
    when "advanced"
      "#{base_classes} bg-green-100 text-green-800"
    when "proficient"
      "#{base_classes} bg-blue-100 text-blue-800"
    when "developing"
      "#{base_classes} bg-yellow-100 text-yellow-800"
    when "novice"
      "#{base_classes} bg-red-100 text-red-800"
    else
      "#{base_classes} bg-gray-100 text-gray-800"
    end
  end
  
  # Get CSS classes for score ranges
  def score_color_classes(score)
    case score
    when 0.8..1.0
      "text-green-600"
    when 0.6..0.8
      "text-blue-600"
    when 0.4..0.6
      "text-yellow-600"
    else
      "text-red-600"
    end
  end
  
  # Format score as percentage
  def format_score_percentage(score)
    "#{(score * 100).round}%"
  end
  
  # Get progress bar color based on score
  def progress_bar_color(score)
    case score
    when 0.8..1.0
      "bg-green-500"
    when 0.6..0.8
      "bg-blue-500"
    when 0.4..0.6
      "bg-yellow-500"
    else
      "bg-red-500"
    end
  end
  
  # Format evaluation timestamp
  def format_evaluation_time(timestamp)
    return "Not evaluated" unless timestamp
    
    if timestamp > 1.day.ago
      time_ago_in_words(timestamp) + " ago"
    else
      timestamp.strftime("%B %d, %Y at %I:%M %p")
    end
  end
  
  # Generate summary statistics for multiple grade reports
  def grade_summary_stats(grade_reports)
    return {} if grade_reports.empty?
    
    scores = grade_reports.map(&:overall_score)
    
    {
      average: (scores.sum / scores.size.to_f).round(2),
      highest: scores.max,
      lowest: scores.min,
      total_count: grade_reports.size,
      recent_count: grade_reports.where(created_at: 1.week.ago..).count
    }
  end
  
  # Check if grade report indicates student needs help
  def needs_attention?(grade_report)
    return false unless grade_report
    
    # Overall score below threshold
    return true if grade_report.overall_score < 0.5
    
    # Multiple concepts below proficient
    struggling_concepts = grade_report.detailed_scores.count do |_, details|
      details['score'] < 0.6
    end
    
    struggling_concepts >= (grade_report.detailed_scores.size / 2.0).ceil
  end
  
  # Get recommended actions based on grade report
  def recommended_actions(grade_report)
    actions = []
    
    if grade_report.overall_score < 0.5
      actions << { 
        type: "urgent", 
        text: "Schedule one-on-one meeting", 
        icon: "exclamation-triangle" 
      }
    end
    
    if grade_report.recommendations.any?
      actions << { 
        type: "info", 
        text: "Review learning recommendations", 
        icon: "light-bulb" 
      }
    end
    
    struggling_concepts = grade_report.detailed_scores.select { |_, details| details['score'] < 0.6 }
    if struggling_concepts.any?
      actions << { 
        type: "warning", 
        text: "Focus on #{struggling_concepts.keys.first(2).join(', ')}", 
        icon: "academic-cap" 
      }
    end
    
    actions
  end
  
  # Format concept name for display
  def format_concept_name(concept)
    concept.to_s.titleize.gsub(/([a-z])([A-Z])/, '\1 \2')
  end
  
  # Get trend indicator for score comparison
  def score_trend_indicator(current_score, previous_score)
    return nil unless previous_score
    
    difference = current_score - previous_score
    
    case difference
    when 0.1..Float::INFINITY
      { direction: "up", color: "text-green-600", icon: "arrow-up" }
    when 0.05..0.1
      { direction: "slight-up", color: "text-green-500", icon: "arrow-up" }
    when -0.05..0.05
      { direction: "stable", color: "text-gray-500", icon: "minus" }
    when -0.1..-0.05
      { direction: "slight-down", color: "text-yellow-500", icon: "arrow-down" }
    else
      { direction: "down", color: "text-red-600", icon: "arrow-down" }
    end
  end
  
  # Generate evaluation insights text
  def evaluation_insights(grade_report)
    insights = []
    
    # Performance level insight
    level = performance_level(grade_report.overall_score)
    insights << "Student is performing at #{level.downcase} level overall"
    
    # Concept distribution
    strong_concepts = grade_report.detailed_scores.select { |_, details| details['score'] >= 0.8 }.keys
    weak_concepts = grade_report.detailed_scores.select { |_, details| details['score'] < 0.5 }.keys
    
    if strong_concepts.any?
      insights << "Strengths: #{strong_concepts.first(2).join(', ')}"
    end
    
    if weak_concepts.any?
      insights << "Areas for improvement: #{weak_concepts.first(2).join(', ')}"
    end
    
    insights
  end
  
end
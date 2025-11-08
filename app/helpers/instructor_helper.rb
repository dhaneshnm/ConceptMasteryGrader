# Helper methods for instructor dashboard functionality
module InstructorHelper
  
  # Format conversation status with appropriate styling
  def conversation_status_badge(conversation)
    if conversation.grade_reports.any?
      latest_report = conversation.grade_reports.order(created_at: :desc).first
      score = latest_report.overall_score
      
      if score >= 0.8
        content_tag(:span, "Excellent", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800")
      elsif score >= 0.6
        content_tag(:span, "Good", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800")
      elsif score >= 0.4
        content_tag(:span, "Fair", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800")
      else
        content_tag(:span, "Needs Help", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800")
      end
    else
      content_tag(:span, "Pending", class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800")
    end
  end
  
  # Calculate engagement level for a conversation
  def engagement_level(conversation)
    user_message_count = conversation.messages.from_user.count
    total_message_count = conversation.messages.count
    
    return "Low" if user_message_count < 3
    return "High" if user_message_count > 10 && total_message_count > 15
    "Medium"
  end
  
  # Get engagement level CSS classes
  def engagement_level_classes(level)
    case level.downcase
    when "high"
      "text-green-600"
    when "medium"
      "text-blue-600"
    else
      "text-gray-600"
    end
  end
  
  # Format misconception severity
  def severity_badge(severity)
    case severity&.downcase
    when "high", "critical"
      content_tag(:span, severity.titleize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800")
    when "medium", "moderate"
      content_tag(:span, severity.titleize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800")
    else
      content_tag(:span, (severity || "Low").titleize, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800")
    end
  end
  
  # Generate quick stats for course material
  def course_material_quick_stats(course_material)
    {
      conversations: course_material.conversations.count,
      evaluated: course_material.conversations.joins(:grade_reports).distinct.count,
      avg_score: course_material.conversations.joins(:grade_reports).average("grade_reports.overall_score")&.round(2) || 0,
      recent_activity: course_material.conversations.where(updated_at: 1.week.ago..).count
    }
  end
  
  # Check if conversation needs instructor attention
  def needs_attention?(conversation)
    return false unless conversation.grade_reports.any?
    
    latest_report = conversation.grade_reports.order(created_at: :desc).first
    
    # Low overall score
    return true if latest_report.overall_score < 0.5
    
    # Multiple failing concepts
    failing_concepts = latest_report.detailed_scores.count do |_, details|
      details['score'] < 0.5
    end
    
    failing_concepts >= (latest_report.detailed_scores.size / 2.0).ceil
  end
  
  # Format analytics percentage
  def format_percentage(value, total)
    return "0%" if total.zero?
    "#{((value / total.to_f) * 100).round(1)}%"
  end
  
  # Get color for score visualization
  def score_color(score)
    case score
    when 0.8..1.0
      "#10B981" # Green
    when 0.6..0.8
      "#3B82F6" # Blue
    when 0.4..0.6
      "#F59E0B" # Yellow
    else
      "#EF4444" # Red
    end
  end
  
  # Format large numbers with K/M suffixes
  def format_count(count)
    return count.to_s if count < 1000
    return "#{(count / 1000.0).round(1)}K" if count < 1_000_000
    "#{(count / 1_000_000.0).round(1)}M"
  end
  
  # Generate trend indicator
  def trend_indicator(current, previous)
    return content_tag(:span, "—", class: "text-gray-500") unless previous && previous > 0
    
    change = ((current - previous) / previous.to_f * 100).round(1)
    
    if change > 0
      content_tag(:span, "↑ #{change}%", class: "text-green-600 font-medium")
    elsif change < 0
      content_tag(:span, "↓ #{change.abs}%", class: "text-red-600 font-medium")
    else
      content_tag(:span, "→ 0%", class: "text-gray-500")
    end
  end
  
  # Priority level for conversations requiring attention
  def attention_priority(conversation)
    return "none" unless needs_attention?(conversation)
    
    latest_report = conversation.grade_reports.order(created_at: :desc).first
    
    return "urgent" if latest_report.overall_score < 0.3
    return "high" if latest_report.overall_score < 0.5
    "medium"
  end
  
  # Format time periods for analytics
  def format_time_period(period)
    case period
    when "day"
      "Daily"
    when "week"
      "Weekly"
    when "month"
      "Monthly"
    else
      period.titleize
    end
  end
  
end
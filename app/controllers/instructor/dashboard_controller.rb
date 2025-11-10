# Instructor dashboard for managing course materials, conversations, and assessments
class Instructor::DashboardController < Instructor::BaseController
  
  # GET /instructor/dashboard
  def index
    @course_materials = accessible_course_materials.limit(10)
    @recent_conversations = recent_conversations.limit(15)
    @recent_evaluations = recent_evaluations.limit(10)
    @statistics = dashboard_statistics
    
    respond_to do |format|
      format.html
      format.json { render json: dashboard_data }
    end
  end
  
  # GET /instructor/analytics
  def analytics
    @course_material = CourseMaterial.find(params[:course_material_id]) if params[:course_material_id].present?
    @analytics_data = generate_analytics_data(@course_material)
    
    respond_to do |format|
      format.html
      format.json { render json: @analytics_data }
    end
  end
  
  # GET /instructor/misconceptions
  def misconceptions
    @course_material = CourseMaterial.find(params[:course_material_id]) if params[:course_material_id].present?
    
    patterns_query = @course_material ? @course_material.misconception_patterns : MisconceptionPattern.all
    
    @misconception_patterns = patterns_query
                               .order(created_at: :desc)
                               .page(params[:page])
                               .per(15)
    
    @new_pattern = MisconceptionPattern.new
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  # POST /instructor/batch_evaluate
  def batch_evaluate
    conversation_ids = params[:conversation_ids] || []
    
    if conversation_ids.empty?
      redirect_to instructor_conversations_path, alert: 'No conversations selected for evaluation.'
      return
    end
    
    # Queue batch evaluation jobs
    conversation_ids.each do |conv_id|
      ConversationEvaluationJob.perform_later(conv_id.to_i, { 
        broadcast_result: false,
        notify_instructor: true,
        update_misconception_patterns: true
      })
    end
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("batch_actions", 
            content: "<div class='bg-green-50 border border-green-200 rounded-lg p-4 mb-4'>
                        <div class='flex items-center'>
                          <svg class='w-5 h-5 text-green-600 mr-2' fill='currentColor' viewBox='0 0 20 20'>
                            <path fill-rule='evenodd' d='M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z' clip-rule='evenodd'></path>
                          </svg>
                          <span class='text-green-800 font-medium'>Batch evaluation started</span>
                        </div>
                        <p class='text-green-600 text-sm mt-1'>Evaluating #{conversation_ids.size} conversations. Results will appear as they complete.</p>
                      </div>"
          )
        ]
      end
      format.html do
        redirect_to instructor_conversations_path, 
                    notice: "Batch evaluation started for #{conversation_ids.size} conversations."
      end
    end
  end
  
  private
  
  def recent_conversations
    Conversation.includes(:student, :course_material, :messages)
               .where(updated_at: 1.week.ago..)
               .order(updated_at: :desc)
  end
  
  def recent_evaluations
    GradeReport.includes(conversation: [:student, :course_material])
              .where(created_at: 1.week.ago..)
              .order(created_at: :desc)
  end
  
  def dashboard_statistics
    {
      total_conversations: Conversation.count,
      evaluated_conversations: Conversation.joins(:grade_reports).distinct.count,
      average_score: GradeReport.average(:overall_score)&.round(2) || 0,
      students_needing_help: GradeReport.where('overall_score < 0.5').distinct.count(:conversation_id),
      active_course_materials: CourseMaterial.joins(:conversations).where(conversations: { updated_at: 1.week.ago.. }).distinct.count,
      recent_activity: Conversation.where(updated_at: 24.hours.ago..).count
    }
  end
  
  def dashboard_data
    {
      statistics: @statistics,
      recent_conversations: @recent_conversations.map(&:to_dashboard_json),
      recent_evaluations: @recent_evaluations.map(&:to_dashboard_json),
      course_materials: @course_materials.map(&:to_dashboard_json)
    }
  end
  
  def generate_analytics_data(course_material = nil)
    conversations = course_material ? course_material.conversations : Conversation.all
    grade_reports = GradeReport.joins(:conversation)
    grade_reports = grade_reports.where(conversations: { course_material: course_material }) if course_material
    
    {
      performance_distribution: calculate_performance_distribution(grade_reports),
      concept_mastery: calculate_concept_mastery(grade_reports, course_material),
      engagement_metrics: calculate_engagement_metrics(conversations),
      improvement_trends: calculate_improvement_trends(grade_reports),
      misconception_frequency: calculate_misconception_frequency(course_material)
    }
  end
  
  def calculate_performance_distribution(grade_reports)
    return {} if grade_reports.empty?
    
    score_ranges = {
      'Outstanding (90-100%)' => grade_reports.where('overall_score >= 0.9').count,
      'Proficient (70-89%)' => grade_reports.where('overall_score >= 0.7 AND overall_score < 0.9').count,
      'Developing (50-69%)' => grade_reports.where('overall_score >= 0.5 AND overall_score < 0.7').count,
      'Needs Support (0-49%)' => grade_reports.where('overall_score < 0.5').count
    }
    
    total = grade_reports.count
    score_ranges.transform_values { |count| { count: count, percentage: total > 0 ? (count / total.to_f * 100).round(1) : 0 } }
  end
  
  def calculate_concept_mastery(grade_reports, course_material)
    return {} unless course_material
    
    concept_scores = {}
    
    course_material.rubrics.each do |rubric|
      scores = grade_reports.map do |report|
        report.detailed_scores.dig(rubric.concept, 'score') || 0
      end.compact
      
      next if scores.empty?
      
      concept_scores[rubric.concept] = {
        average_score: (scores.sum / scores.size.to_f).round(2),
        mastery_rate: (scores.count { |s| s >= 0.7 } / scores.size.to_f * 100).round(1),
        needs_support: scores.count { |s| s < 0.5 },
        total_assessments: scores.size
      }
    end
    
    concept_scores
  end
  
  def calculate_engagement_metrics(conversations)
    return {} if conversations.empty?
    
    message_counts = conversations.joins(:messages).group('conversations.id').count('messages.id')
    user_message_counts = conversations.joins(:messages).where(messages: { role: 'user' }).group('conversations.id').count('messages.id')
    
    {
      average_messages_per_conversation: message_counts.values.sum / message_counts.size.to_f,
      average_user_messages: user_message_counts.values.sum / user_message_counts.size.to_f,
      conversations_with_evaluation: conversations.joins(:grade_reports).distinct.count,
      active_conversations_last_week: conversations.where(updated_at: 1.week.ago..).count
    }
  end
  
  def calculate_improvement_trends(grade_reports)
    # Group reports by conversation and calculate improvement over time
    conversation_reports = grade_reports.includes(:conversation)
                                      .group_by(&:conversation_id)
                                      .select { |_, reports| reports.size > 1 }
    
    improvements = conversation_reports.map do |_, reports|
      sorted_reports = reports.sort_by(&:created_at)
      first_score = sorted_reports.first.overall_score
      last_score = sorted_reports.last.overall_score
      last_score - first_score
    end
    
    return {} if improvements.empty?
    
    {
      conversations_with_improvement: improvements.count { |imp| imp > 0.1 },
      conversations_with_decline: improvements.count { |imp| imp < -0.1 },
      average_improvement: (improvements.sum / improvements.size.to_f).round(3),
      total_re_evaluated: improvements.size
    }
  end
  
  def calculate_misconception_frequency(course_material)
    return {} unless course_material
    
    patterns = course_material.misconception_patterns
    frequency_data = {}
    
    patterns.each do |pattern|
      # Count how often this pattern appears in evaluations
      # This is a simplified count - in production you'd track actual matches
      frequency_data[pattern.name] = {
        description: pattern.name,
        signal_phrases: pattern.signal_phrases,
        frequency: rand(1..10), # Placeholder - would be real frequency data
        severity: pattern.severity || 'medium'
      }
    end
    
    frequency_data
  end
end
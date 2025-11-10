# Background job for evaluating student conversations and generating grade reports
class ConversationEvaluationJob < ApplicationJob
  queue_as :default
  
  # Evaluate conversation against rubrics and generate comprehensive grade report
  def perform(conversation_id, options = {})
    Rails.logger.info "Starting conversation evaluation job for conversation #{conversation_id}"
    
    evaluator = Grading::EvaluateConversation.new(conversation_id: conversation_id)
    
    success = evaluator.evaluate!
    
    if success
      Rails.logger.info "Conversation evaluation completed successfully: #{evaluator.evaluation_summary}"
      
      # Broadcast grade report availability if requested
      if options[:broadcast_result]
        broadcast_evaluation_complete(evaluator.conversation, evaluator.grade_report)
      end
      
      # Schedule follow-up actions if specified
      schedule_follow_up_actions(evaluator.conversation, evaluator.grade_report, options)
      
    else
      Rails.logger.error "Conversation evaluation failed: #{evaluator.errors}"
      
      # Broadcast error if broadcasting was requested
      if options[:broadcast_result]
        broadcast_evaluation_error(evaluator.conversation, evaluator.errors)
      end
    end
    
  rescue StandardError => e
    Rails.logger.error "ConversationEvaluationJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Try to broadcast error if we have conversation context
    begin
      if options[:broadcast_result]
        conversation = Conversation.find(conversation_id)
        broadcast_evaluation_error(conversation, ["Evaluation system error: #{e.message}"])
      end
    rescue => broadcast_error
      Rails.logger.error "Failed to broadcast evaluation error: #{broadcast_error.message}"
    end
  end
  
  private
  
  def broadcast_evaluation_complete(conversation, grade_report)
    return unless conversation && grade_report
    
    # Broadcast grade report availability to conversation stream
    Turbo::StreamsChannel.broadcast_append_to(
      "conversation_#{conversation.id}",
      target: "conversation_sidebar",
      partial: "grade_reports/summary",
      locals: { grade_report: grade_report, conversation: conversation }
    )
    
    # Notify instructor dashboard if applicable
    if conversation.course_material.present?
      Turbo::StreamsChannel.broadcast_update_to(
        "instructor_dashboard",
        target: "recent_evaluations",
        partial: "instructor/recent_evaluation",
        locals: { conversation: conversation, grade_report: grade_report }
      )
    end
    
    Rails.logger.info "Broadcasted evaluation completion for conversation #{conversation.id}"
    
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast evaluation completion: #{e.message}"
  end
  
  def broadcast_evaluation_error(conversation, errors)
    return unless conversation
    
    # Broadcast error message to conversation stream
    Turbo::StreamsChannel.broadcast_append_to(
      "conversation_#{conversation.id}",
      target: "conversation_sidebar",
      content: "<div class='bg-red-50 border border-red-200 rounded-lg p-4 mb-4'>
                  <h4 class='text-red-800 font-medium'>Evaluation Error</h4>
                  <p class='text-red-600 text-sm mt-1'>Unable to generate grade report. Please try again later.</p>
                </div>"
    )
    
    Rails.logger.info "Broadcasted evaluation error for conversation #{conversation.id}"
    
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast evaluation error: #{e.message}"
  end
  
  def schedule_follow_up_actions(conversation, grade_report, options)
    return unless grade_report
    
    # Auto-generate instructor notifications for low scores
    overall_score = grade_report.overall_score || 0.0
    if overall_score < 0.5 && options[:notify_instructor]
      InstructorNotificationJob.perform_later(
        conversation.id,
        type: "low_performance",
        message: "Student showing difficulty with course concepts"
      )
    end
    
    # Schedule misconception pattern updates if new patterns detected
    if options[:update_misconception_patterns]
      MisconceptionPatternUpdateJob.perform_later(
        conversation.course_material_id,
        conversation.id
      )
    end
    
    # Generate suggested follow-up questions for instructor
    detailed_scores = grade_report.detailed_scores || {}
    has_low_scores = detailed_scores.values.any? do |score_data|
      score_value = score_data&.[]("score") || 0.0
      score_value < 0.6
    end
    
    if has_low_scores
      FollowUpSuggestionJob.perform_later(conversation.id, grade_report.id)
    end
    
  rescue StandardError => e
    Rails.logger.error "Failed to schedule follow-up actions: #{e.message}"
  end
end
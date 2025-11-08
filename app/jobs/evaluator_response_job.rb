# Background job for generating AI evaluator responses to student messages
class EvaluatorResponseJob < ApplicationJob
  queue_as :default
  
  # Generate AI response to student message using RAG-based evaluation
  def perform(conversation_id, student_message_id)
    Rails.logger.info "Starting evaluator response generation for conversation #{conversation_id}, message #{student_message_id}"
    
    generator = Evaluator::ResponseGenerator.new(
      conversation_id: conversation_id,
      student_message_id: student_message_id
    )
    
    success = generator.generate!
    
    if success
      Rails.logger.info "Evaluator response generated successfully: #{generator.generation_summary}"
      
      # Broadcast the AI response via Turbo Stream
      broadcast_ai_response(generator.conversation, generator.generated_response)
      
    else
      Rails.logger.error "Evaluator response generation failed: #{generator.errors}"
      
      # Broadcast error message
      broadcast_error_response(generator.conversation, generator.errors)
    end
    
  rescue StandardError => e
    Rails.logger.error "EvaluatorResponseJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Try to broadcast error if we have conversation context
    begin
      conversation = Conversation.find(conversation_id)
      broadcast_error_response(conversation, ["An error occurred while generating response: #{e.message}"])
    rescue => broadcast_error
      Rails.logger.error "Failed to broadcast error: #{broadcast_error.message}"
    end
  end
  
  private
  
  def broadcast_ai_response(conversation, ai_message)
    return unless conversation && ai_message
    
    # Broadcast new AI message to conversation stream
    Turbo::StreamsChannel.broadcast_append_to(
      "conversation_#{conversation.id}",
      target: "messages",
      partial: "messages/message",
      locals: { message: ai_message }
    )
    
    # Update typing indicator to hide
    Turbo::StreamsChannel.broadcast_update_to(
      "conversation_#{conversation.id}",
      target: "typing_indicator",
      content: ""
    )
    
    Rails.logger.info "Broadcasted AI response for conversation #{conversation.id}"
    
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast AI response: #{e.message}"
  end
  
  def broadcast_error_response(conversation, errors)
    return unless conversation
    
    error_message = conversation.messages.create!(
      role: "assistant",
      content: "I apologize, but I encountered an error while processing your message. Please try again or contact support if the problem persists."
    )
    
    # Broadcast error message
    Turbo::StreamsChannel.broadcast_append_to(
      "conversation_#{conversation.id}",
      target: "messages", 
      partial: "messages/message",
      locals: { message: error_message }
    )
    
    # Hide typing indicator
    Turbo::StreamsChannel.broadcast_update_to(
      "conversation_#{conversation.id}",
      target: "typing_indicator",
      content: ""
    )
    
    Rails.logger.info "Broadcasted error response for conversation #{conversation.id}"
    
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast error response: #{e.message}"
  end
end
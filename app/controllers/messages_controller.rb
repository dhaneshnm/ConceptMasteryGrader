# Controller for managing chat messages with Turbo Streams support.
class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: [:destroy]
  
  # POST /conversations/1/messages
  def create
    @message = @conversation.messages.build(message_params)
    
    Rails.logger.info "Creating message: #{@message.attributes.inspect}"
    Rails.logger.info "Message valid? #{@message.valid?}"
    Rails.logger.info "Message errors: #{@message.errors.full_messages}" unless @message.valid?
    
    respond_to do |format|
      if @message.save
        Rails.logger.info "Message saved successfully with ID: #{@message.id}"
        
        # Trigger AI response generation in background only for user messages
        if @message.from_user?
          EvaluatorResponseJob.perform_later(@conversation.id, @message.id)
        end
        
        format.turbo_stream
        # The turbo_stream template handles the rendering
        format.html { redirect_to [@conversation.course_material, @conversation] }
      else
        Rails.logger.error "Failed to save message: #{@message.errors.full_messages}"
        
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("message_form", partial: "messages/form", locals: {
            conversation: @conversation,
            message: @message
          })
        end
        format.html { redirect_to [@conversation.course_material, @conversation] }
      end
    end
  end
  
  # DELETE /conversations/1/messages/1
  def destroy
    @message.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@message)
      end
      format.html { redirect_to [@conversation.course_material, @conversation] }
    end
  end
  
  private
  
  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end
  
  def set_message
    @message = @conversation.messages.find(params[:id])
  end
  
  def message_params
    params.require(:message).permit(:content, :role)
  end
end
# Controller for managing chat messages with Turbo Streams support.
class MessagesController < ApplicationController
  before_action :set_conversation
  before_action :set_message, only: [:show, :destroy]
  
  # POST /conversations/1/messages
  def create
    @message = @conversation.messages.build(message_params)
    
    respond_to do |format|
      if @message.save
        # Trigger AI response generation in background only for user messages
        if @message.from_user?
          EvaluatorResponseJob.perform_later(@conversation.id, @message.id)
        end
        
        format.turbo_stream do
          streams = [
            turbo_stream.append("messages", partial: "messages/message", locals: { message: @message }),
            turbo_stream.replace("message_form", partial: "messages/form", locals: { 
              conversation: @conversation, 
              message: @conversation.messages.build 
            })
          ]
          
          # Add typing indicator only for user messages
          if @message.from_user?
            streams << turbo_stream.update("typing_indicator", 
              content: "<div class='flex items-center text-gray-500 text-sm py-2'><div class='typing-dots mr-2'><span></span><span></span><span></span></div>AI is thinking...</div>"
            )
          end
          
          render turbo_stream: streams
        end
        format.html { redirect_to [@conversation.course_material, @conversation] }
      else
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
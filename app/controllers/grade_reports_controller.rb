# Controller for managing grade reports and conversation evaluations
class GradeReportsController < ApplicationController
  before_action :set_conversation
  before_action :set_grade_report, only: [:show, :destroy]
  
  # GET /course_materials/1/conversations/1/grade_reports
  def index
    @grade_reports = @conversation.grade_reports.order(created_at: :desc)
    
    respond_to do |format|
      format.html
      format.json { render json: @grade_reports }
    end
  end
  
  # GET /course_materials/1/conversations/1/grade_reports/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @grade_report }
      format.turbo_stream
    end
  end
  
  # POST /course_materials/1/conversations/1/grade_reports
  def create
    # Check if evaluation is already in progress
    if evaluation_in_progress?
      redirect_to [@conversation.course_material, @conversation], 
                  alert: 'Evaluation is already in progress for this conversation.'
      return
    end
    
    # Validate conversation has sufficient content
    unless @conversation.messages.from_user.count >= 2
      redirect_to [@conversation.course_material, @conversation],
                  alert: 'Conversation must have at least 2 student messages to evaluate.'
      return
    end
    
    # Validate rubrics exist
    unless @conversation.course_material.rubrics.exists?
      redirect_to [@conversation.course_material, @conversation],
                  alert: 'Course material must have rubrics before evaluation.'
      return
    end
    
    begin
      # Queue evaluation job
      job_options = {
        broadcast_result: true,
        notify_instructor: params[:notify_instructor] == 'true',
        update_misconception_patterns: params[:update_patterns] == 'true'
      }
      
      ConversationEvaluationJob.perform_later(@conversation.id, job_options)
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("evaluation_status", 
              content: "<div class='bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4'>
                          <div class='flex items-center'>
                            <div class='animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2'></div>
                            <span class='text-blue-800 font-medium'>Evaluating conversation...</span>
                          </div>
                          <p class='text-blue-600 text-sm mt-1'>This may take a few moments to complete.</p>
                        </div>"
            )
          ]
        end
        format.html do
          redirect_to [@conversation.course_material, @conversation], 
                      notice: 'Evaluation started. Results will appear shortly.'
        end
      end
      
    rescue StandardError => e
      Rails.logger.error "Failed to start evaluation: #{e.message}"
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update("evaluation_status",
            content: "<div class='bg-red-50 border border-red-200 rounded-lg p-4 mb-4'>
                        <h4 class='text-red-800 font-medium'>Evaluation Error</h4>
                        <p class='text-red-600 text-sm mt-1'>Unable to start evaluation. Please try again.</p>
                      </div>"
          )
        end
        format.html do
          redirect_to [@conversation.course_material, @conversation],
                      alert: 'Unable to start evaluation. Please try again.'
        end
      end
    end
  end
  
  # DELETE /course_materials/1/conversations/1/grade_reports/1
  def destroy
    @grade_report.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@grade_report)
      end
      format.html do
        redirect_to [@conversation.course_material, @conversation], 
                    notice: 'Grade report was successfully deleted.'
      end
    end
  end
  
  # GET /course_materials/1/conversations/1/grade_reports/latest
  def latest
    @grade_report = @conversation.grade_reports.order(created_at: :desc).first
    
    if @grade_report
      redirect_to [@conversation.course_material, @conversation, @grade_report]
    else
      redirect_to [@conversation.course_material, @conversation],
                  alert: 'No grade reports found for this conversation.'
    end
  end
  
  # POST /course_materials/1/conversations/1/grade_reports/batch_evaluate
  def batch_evaluate
    # Evaluate multiple conversations at once (instructor feature)
    conversation_ids = params[:conversation_ids] || []
    
    if conversation_ids.empty?
      redirect_to course_material_path(@conversation.course_material),
                  alert: 'No conversations selected for evaluation.'
      return
    end
    
    # Queue batch evaluation
    conversation_ids.each do |conv_id|
      ConversationEvaluationJob.perform_later(conv_id.to_i, { 
        broadcast_result: false,
        notify_instructor: true 
      })
    end
    
    redirect_to course_material_path(@conversation.course_material),
                notice: "Batch evaluation started for #{conversation_ids.size} conversations."
  end
  
  private
  
  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end
  
  def set_grade_report
    @grade_report = @conversation.grade_reports.find(params[:id])
  end
  
  def evaluation_in_progress?
    # Check if there's a recent evaluation job in progress
    # This is a simplified check - in production you might want to use job status tracking
    last_report = @conversation.grade_reports.order(created_at: :desc).first
    return false unless last_report
    
    # Consider evaluation in progress if last report was created less than 2 minutes ago
    last_report.created_at > 2.minutes.ago
  end
end
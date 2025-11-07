# Instructor conversations management controller
class Instructor::ConversationsController < Instructor::BaseController
  
  # GET /instructor/conversations
  def index
    @course_material = CourseMaterial.find(params[:course_material_id]) if params[:course_material_id].present?
    
    conversations_query = @course_material ? @course_material.conversations : Conversation.all
    
    @conversations = conversations_query
                      .includes(:student, :course_material, :grade_reports, :messages)
                      .order(updated_at: :desc)
                      .page(params[:page])
                      .per(20)
    
    # Filter options
    if params[:status].present?
      case params[:status]
      when 'evaluated'
        @conversations = @conversations.joins(:grade_reports).distinct
      when 'pending'
        @conversations = @conversations.left_joins(:grade_reports).where(grade_reports: { id: nil })
      when 'needs_attention'
        @conversations = @conversations.joins(:grade_reports).where('grade_reports.overall_score < 0.5')
      end
    end
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
end
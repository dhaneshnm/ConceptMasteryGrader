# Controller for managing interactive evaluation conversations.
class ConversationsController < ApplicationController
  before_action :set_course_material
  before_action :set_conversation, only: [:show, :destroy]
  
  # GET /course_materials/1/conversations
  def index
    @conversations = @course_material.conversations
                                   .includes(:student, :messages)
                                   .order(updated_at: :desc)
  end
  
  # GET /course_materials/1/conversations/1
  def show
    @messages = @conversation.ordered_messages.includes(:conversation)
    @new_message = @conversation.messages.build
  end
  
  # GET /course_materials/1/conversations/new
  def new
    @conversation = @course_material.conversations.build
    @students = Student.order(:name)
  end
  
  # POST /course_materials/1/conversations
  def create
    @student = find_or_create_student
    @conversation = @course_material.conversations.build(student: @student)
    
    if @conversation.save
      redirect_to [@course_material, @conversation], 
                  notice: 'Evaluation session started successfully.'
    else
      @students = Student.order(:name)
      render :new, status: :unprocessable_entity
    end
  end
  
  # DELETE /course_materials/1/conversations/1
  def destroy
    @conversation.destroy
    redirect_to [@course_material, :conversations], 
                notice: 'Conversation deleted successfully.'
  end
  
  private
  
  def set_course_material
    @course_material = CourseMaterial.find(params[:course_material_id])
  end
  
  def set_conversation
    @conversation = @course_material.conversations.find(params[:id])
  end
  
  def find_or_create_student
    if params[:conversation][:existing_student_id].present?
      Student.find(params[:conversation][:existing_student_id])
    else
      student_params = params[:conversation].permit(:student_name, :student_email)
      Student.find_or_create_by(email: student_params[:student_email]) do |student|
        student.name = student_params[:student_name]
      end
    end
  end
end
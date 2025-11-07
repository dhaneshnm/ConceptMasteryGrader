# Controller for managing course material summaries.
class SummariesController < ApplicationController
  before_action :set_course_material
  before_action :set_summary, only: [:show, :destroy]
  
  # GET /course_materials/1/summaries
  def index
    @summaries = [@course_material.summary].compact
  end
  
  # GET /course_materials/1/summary
  def show
    unless @summary
      redirect_to @course_material, alert: 'No summary available for this course material.'
    end
  end
  
  # POST /course_materials/1/summary
  def create
    unless @course_material.processed?
      redirect_to @course_material, 
                  alert: 'Course material must be processed before generating summary.'
      return
    end
    
    if @course_material.summary.present?
      redirect_to [@course_material, @course_material.summary], 
                  notice: 'Summary already exists.'
      return
    end
    
    SummaryGenerationJob.perform_later(@course_material.id)
    redirect_to @course_material, 
                notice: 'Summary generation started. This may take a few minutes.'
  end
  
  # DELETE /course_materials/1/summary
  def destroy
    if @course_material.summary&.destroy
      redirect_to @course_material, notice: 'Summary deleted successfully.'
    else
      redirect_to @course_material, alert: 'Failed to delete summary.'
    end
  end
  
  private
  
  def set_course_material
    @course_material = CourseMaterial.find(params[:course_material_id])
  end
  
  def set_summary
    @summary = @course_material.summary
  end
end
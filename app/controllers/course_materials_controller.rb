# Controller for managing course material uploads and processing.
class CourseMaterialsController < ApplicationController
  before_action :set_course_material, only: [:show, :destroy, :generate_summary]
  
  # GET /course_materials
  def index
    @course_materials = CourseMaterial.includes(:chunks, :summary)
                                     .order(created_at: :desc)
  end
  
  # GET /course_materials/1
  def show
    @chunks_count = @course_material.chunks.count
    @summary = @course_material.summary
    @processing_status = @course_material.status
  end
  
  # GET /course_materials/new
  def new
    @course_material = CourseMaterial.new
  end
  
  # POST /course_materials
  def create
    @course_material = CourseMaterial.new(course_material_params)
    
    if @course_material.save
      redirect_to @course_material, 
                  notice: 'Course material uploaded successfully. Processing will begin shortly.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  # POST /course_materials/1/generate_summary
  def generate_summary
    unless @course_material.processed?
      redirect_to @course_material, 
                  alert: 'Course material must be processed before generating summary.'
      return
    end
    
    if @course_material.summary.present?
      redirect_to @course_material, 
                  notice: 'Summary already exists for this course material.'
      return
    end
    
    SummaryGenerationJob.perform_later(@course_material.id)
    redirect_to @course_material, 
                notice: 'Summary generation started. This may take a few minutes.'
  end
  
  # DELETE /course_materials/1
  def destroy
    @course_material.destroy
    redirect_to course_materials_url, notice: 'Course material was deleted successfully.'
  end
  
  private
  
  def set_course_material
    @course_material = CourseMaterial.find(params[:id])
  end
  
  def course_material_params
    params.require(:course_material).permit(:title, files: [])
  end
end
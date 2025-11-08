# Controller for managing course material rubrics.
class RubricsController < ApplicationController
  before_action :set_course_material
  before_action :set_rubric, only: [:show, :edit, :update, :destroy]
  
  # GET /course_materials/1/rubrics
  def index
    @rubrics = @course_material.rubrics.order(:concept)
  end
  
  # GET /course_materials/1/rubrics/1
  def show
  end
  
  # POST /course_materials/1/rubrics/generate
  def generate
    unless @course_material.processed?
      redirect_to [@course_material, :rubrics], 
                  alert: 'Course material must be processed before generating rubrics.'
      return
    end
    
    RubricGenerationJob.perform_later(@course_material.id)
    redirect_to [@course_material, :rubrics], 
                notice: 'Rubric generation started. This may take a few minutes.'
  end
  
  # GET /course_materials/1/rubrics/1/edit
  def edit
  end
  
  # PATCH /course_materials/1/rubrics/1
  def update
    if @rubric.update(rubric_params)
      redirect_to [@course_material, @rubric], 
                  notice: 'Rubric updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  # DELETE /course_materials/1/rubrics/1
  def destroy
    @rubric.destroy
    redirect_to [@course_material, :rubrics], 
                notice: 'Rubric deleted successfully.'
  end
  
  private
  
  def set_course_material
    @course_material = CourseMaterial.find(params[:course_material_id])
  end
  
  def set_rubric
    @rubric = @course_material.rubrics.find(params[:id]) if params[:id]
  end
  
  def rubric_params
    params.require(:rubric).permit(:concept, levels: {})
  end
end
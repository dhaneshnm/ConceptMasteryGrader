# Controller for managing misconception patterns - instructor can add, edit, and organize common misconceptions
class Instructor::MisconceptionPatternsController < Instructor::BaseController
  before_action :set_course_material
  before_action :set_misconception_pattern, only: [:show, :edit, :update, :destroy]
  
  # GET /instructor/course_materials/1/misconception_patterns
  def index
    @misconception_patterns = @course_material.misconception_patterns
                                             .order(:severity, :created_at)
                                             .page(params[:page])
                                             .per(20)
    
    @new_pattern = @course_material.misconception_patterns.build
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  # GET /instructor/course_materials/1/misconception_patterns/1
  def show
    respond_to do |format|
      format.html
      format.json { render json: @misconception_pattern }
    end
  end
  
  # GET /instructor/course_materials/1/misconception_patterns/new
  def new
    @misconception_pattern = @course_material.misconception_patterns.build
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
  
  # GET /instructor/course_materials/1/misconception_patterns/1/edit
  def edit
    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "misconception_pattern_#{@misconception_pattern.id}",
          partial: "instructor/misconception_patterns/form",
          locals: { misconception_pattern: @misconception_pattern, course_material: @course_material }
        )
      end
    end
  end
  
  # POST /instructor/course_materials/1/misconception_patterns
  def create
    @misconception_pattern = @course_material.misconception_patterns.build(misconception_pattern_params)
    
    respond_to do |format|
      if @misconception_pattern.save
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.prepend("misconception_patterns_list", 
              partial: "instructor/misconception_patterns/pattern",
              locals: { pattern: @misconception_pattern }
            ),
            turbo_stream.replace("new_pattern_form",
              partial: "instructor/misconception_patterns/form",
              locals: { 
                misconception_pattern: @course_material.misconception_patterns.build,
                course_material: @course_material
              }
            )
          ]
        end
        format.html { redirect_to instructor_course_material_misconception_patterns_path(@course_material), notice: 'Misconception pattern was successfully created.' }
        format.json { render :show, status: :created, location: [@course_material, @misconception_pattern] }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("new_pattern_form",
            partial: "instructor/misconception_patterns/form",
            locals: { 
              misconception_pattern: @misconception_pattern,
              course_material: @course_material
            }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @misconception_pattern.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # PATCH/PUT /instructor/course_materials/1/misconception_patterns/1
  def update
    respond_to do |format|
      if @misconception_pattern.update(misconception_pattern_params)
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "misconception_pattern_#{@misconception_pattern.id}",
            partial: "instructor/misconception_patterns/pattern",
            locals: { pattern: @misconception_pattern }
          )
        end
        format.html { redirect_to instructor_course_material_misconception_patterns_path(@course_material), notice: 'Misconception pattern was successfully updated.' }
        format.json { render :show, status: :ok, location: [@course_material, @misconception_pattern] }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "misconception_pattern_#{@misconception_pattern.id}",
            partial: "instructor/misconception_patterns/form",
            locals: { 
              misconception_pattern: @misconception_pattern,
              course_material: @course_material
            }
          )
        end
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @misconception_pattern.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /instructor/course_materials/1/misconception_patterns/1
  def destroy
    @misconception_pattern.destroy
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("misconception_pattern_#{@misconception_pattern.id}")
      end
      format.html { redirect_to instructor_course_material_misconception_patterns_path(@course_material), notice: 'Misconception pattern was successfully deleted.' }
      format.json { head :no_content }
    end
  end
  
  # POST /instructor/course_materials/1/misconception_patterns/detect_from_conversations
  def detect_from_conversations
    # Use AI to analyze conversations and suggest new misconception patterns
    conversations = @course_material.conversations
                                   .joins(:messages)
                                   .where(messages: { role: 'user' })
                                   .includes(:messages)
                                   .limit(50)
    
    if conversations.empty?
      redirect_to instructor_course_material_misconception_patterns_path(@course_material),
                  alert: 'No conversations found to analyze for misconceptions.'
      return
    end
    
    # Queue background job to analyze conversations for patterns
    MisconceptionDetectionJob.perform_later(@course_material.id, conversations.pluck(:id))
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("detection_status",
          content: "<div class='bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4'>
                      <div class='flex items-center'>
                        <div class='animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600 mr-2'></div>
                        <span class='text-blue-800 font-medium'>Analyzing conversations...</span>
                      </div>
                      <p class='text-blue-600 text-sm mt-1'>Detecting common misconception patterns from #{conversations.count} conversations.</p>
                    </div>"
        )
      end
      format.html do
        redirect_to instructor_course_material_misconception_patterns_path(@course_material),
                    notice: "Started analyzing #{conversations.count} conversations for misconception patterns."
      end
    end
  end
  
  private
  
  def set_course_material
    @course_material = CourseMaterial.find(params[:course_material_id])
  end
  
  def set_misconception_pattern
    @misconception_pattern = @course_material.misconception_patterns.find(params[:id])
  end
  
  def misconception_pattern_params
    params.require(:misconception_pattern).permit(:pattern, :description, :severity, :suggested_response)
  end
end
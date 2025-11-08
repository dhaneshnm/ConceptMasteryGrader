# RAG-based service for generating structured course summaries.
# Retrieves relevant chunks using semantic similarity and synthesizes them into comprehensive summaries.
class Summaries::Generate
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :course_material_id, :integer
  
  validates :course_material_id, presence: true
  
  attr_reader :course_material, :generated_summary, :errors, :chunks_used
  
  def initialize(attributes = {})
    super
    @errors = []
    @chunks_used = []
    @generated_summary = nil
  end
  
  # Generate a comprehensive summary for the course material
  def generate!
    return false unless valid?
    
    load_course_material
    return false unless course_material&.processed?
    
    # Check if summary already exists
    if course_material.summary.present?
      @generated_summary = course_material.summary
      add_error("Summary already exists for this course material")
      return false
    end
    
    begin
      # Retrieve diverse chunks for comprehensive coverage
      relevant_chunks = retrieve_diverse_chunks
      return false if relevant_chunks.empty?
      
      # Generate summary using LLM
      summary_content = generate_summary_content(relevant_chunks)
      return false unless summary_content
      
      # Save the summary
      save_summary(summary_content)
      
      true
    rescue StandardError => e
      add_error("Summary generation failed: #{e.message}")
      Rails.logger.error "Summary generation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  # Get generation results summary
  def generation_summary
    {
      course_material_id: course_material_id,
      chunks_analyzed: chunks_used.size,
      summary_generated: generated_summary.present?,
      summary_length: generated_summary&.content&.length || 0,
      success: errors.empty?,
      errors: errors
    }
  end
  
  private
  
  def load_course_material
    @course_material = CourseMaterial.find_by(id: course_material_id)
    unless @course_material
      add_error("Course material not found with id: #{course_material_id}")
      return false
    end
    
    unless @course_material.processed?
      add_error("Course material must be processed before generating summary")
      return false
    end
    
    if @course_material.chunks.empty?
      add_error("No chunks available for summary generation")
      return false
    end
    
    true
  end
  
  def retrieve_diverse_chunks
    chunks = course_material.chunks.includes(:course_material)
    
    if chunks.count <= 10
      # Use all chunks if we have 10 or fewer
      @chunks_used = chunks.to_a
      return @chunks_used
    end
    
    # For larger documents, use clustering approach to get diverse chunks
    # This ensures we cover different topics/sections of the material
    selected_chunks = select_diverse_chunks(chunks)
    @chunks_used = selected_chunks
    
    Rails.logger.info "Selected #{selected_chunks.size} diverse chunks for summary generation"
    selected_chunks
  end
  
  def select_diverse_chunks(chunks, max_chunks: 15)
    # Simple diversity selection: take chunks at regular intervals
    # plus some random sampling to ensure coverage
    total_chunks = chunks.count
    return chunks.limit(max_chunks).to_a if total_chunks <= max_chunks
    
    # Take chunks at regular intervals to ensure document coverage
    interval = total_chunks / (max_chunks * 0.7).to_i # Use 70% for interval sampling
    interval_chunks = []
    
    (0...total_chunks).step(interval).each do |i|
      chunk = chunks.offset(i).first
      interval_chunks << chunk if chunk
      break if interval_chunks.size >= (max_chunks * 0.7).to_i
    end
    
    # Fill remaining slots with random chunks
    remaining_slots = max_chunks - interval_chunks.size
    if remaining_slots > 0
      used_ids = interval_chunks.map(&:id)
      random_chunks = chunks.where.not(id: used_ids)
                           .order("RANDOM()")
                           .limit(remaining_slots)
      interval_chunks.concat(random_chunks.to_a)
    end
    
    # Sort by original order for coherent processing
    interval_chunks.sort_by { |chunk| chunks.find_index(chunk) || 0 }
  end
  
  def generate_summary_content(chunks)
    # Prepare context from chunks
    chunks_context = chunks.map.with_index do |chunk, index|
      "--- Chunk #{index + 1} ---\n#{chunk.text.strip}"
    end.join("\n\n")
    
    # Generate summary using LLM
    messages = [
      {
        role: "system", 
        content: build_system_prompt
      },
      {
        role: "user",
        content: build_user_prompt(chunks_context)
      }
    ]
    
    Rails.logger.info "Generating summary for course material #{course_material_id} using #{chunks.size} chunks"
    
    response = LLM.chat(messages: messages)
    
    if response && response.strip.present?
      Rails.logger.info "Successfully generated summary (#{response.length} characters)"
      response.strip
    else
      add_error("Empty response from LLM")
      nil
    end
  rescue StandardError => e
    add_error("LLM communication failed: #{e.message}")
    Rails.logger.error "LLM error in summary generation: #{e.message}"
    nil
  end
  
  def build_system_prompt
    <<~PROMPT
      You are an expert educational content analyzer. Your task is to create a comprehensive, structured summary of course material based on text chunks extracted from educational documents.

      Your summary should:
      1. **Identify the main subject/topic** of the course material
      2. **Extract key concepts and learning objectives** covered in the material
      3. **Organize content into logical sections** with clear headings
      4. **Highlight important definitions, formulas, or principles**
      5. **Note any prerequisites or foundational knowledge assumed**
      6. **Identify practical applications or examples** mentioned
      7. **Maintain academic rigor** while being accessible

      Format your response as a well-structured summary with:
      - Clear section headers (use ## for main sections)
      - Bullet points for key concepts
      - Proper terminology and academic language
      - Logical flow from fundamental concepts to applications

      Focus on creating a summary that would help an instructor understand the scope and depth of the material for assessment purposes.
    PROMPT
  end
  
  def build_user_prompt(chunks_context)
    <<~PROMPT
      Please analyze the following course material chunks and create a comprehensive structured summary:

      #{chunks_context}

      Based on these chunks, create a detailed summary that captures the essential learning content, key concepts, and educational objectives of this material.
    PROMPT
  end
  
  def save_summary(content)
    @generated_summary = course_material.build_summary(content: content)
    
    if @generated_summary.save
      Rails.logger.info "Successfully saved summary for course material #{course_material_id}"
      true
    else
      @generated_summary.errors.full_messages.each { |error| add_error(error) }
      Rails.logger.error "Failed to save summary: #{@generated_summary.errors.full_messages.join(', ')}"
      false
    end
  rescue StandardError => e
    add_error("Failed to save summary: #{e.message}")
    Rails.logger.error "Summary save error: #{e.message}"
    false
  end
  
  def add_error(message)
    @errors << message
  end
end
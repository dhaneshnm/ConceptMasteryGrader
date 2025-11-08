# RAG-based service for generating assessment rubrics from course materials.
# Extracts key concepts and creates detailed rubrics with proficiency levels.
class Rubrics::Generate
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :course_material_id, :integer
  
  validates :course_material_id, presence: true
  
  attr_reader :course_material, :generated_rubrics, :errors
  
  def initialize(attributes = {})
    super
    @errors = []
    @generated_rubrics = []
  end
  
  # Generate rubrics for the course material
  def generate!
    return false unless valid?
    
    load_course_material
    return false unless course_material&.processed?
    
    begin
      # Get or generate summary for concept extraction
      summary = ensure_summary_exists
      return false unless summary
      
      # Extract key concepts from summary and chunks
      concepts = extract_key_concepts(summary)
      return false if concepts.empty?
      
      # Generate rubric for each concept
      concepts.each do |concept_info|
        rubric = generate_concept_rubric(concept_info)
        @generated_rubrics << rubric if rubric
      end
      
      return false if @generated_rubrics.empty?
      
      Rails.logger.info "Successfully generated #{@generated_rubrics.size} rubrics for course material #{course_material_id}"
      true
      
    rescue StandardError => e
      add_error("Rubric generation failed: #{e.message}")
      Rails.logger.error "Rubric generation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  # Get generation results summary
  def generation_summary
    {
      course_material_id: course_material_id,
      rubrics_generated: generated_rubrics.size,
      concepts_covered: generated_rubrics.map(&:concept),
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
      add_error("Course material must be processed before generating rubrics")
      return false
    end
    
    true
  end
  
  def ensure_summary_exists
    summary = course_material.summary
    
    unless summary
      # Generate summary first if it doesn't exist
      Rails.logger.info "No summary found, generating one first for rubric creation"
      summary_service = Summaries::Generate.new(course_material_id: course_material_id)
      
      if summary_service.generate!
        summary = course_material.reload.summary
      else
        add_error("Failed to generate required summary: #{summary_service.errors.join(', ')}")
        return nil
      end
    end
    
    summary
  end
  
  def extract_key_concepts(summary)
    # Use LLM to identify key concepts from the summary
    messages = [
      {
        role: "system",
        content: build_concept_extraction_prompt
      },
      {
        role: "user", 
        content: "Extract key concepts from this course summary:\n\n#{summary.content}"
      }
    ]
    
    Rails.logger.info "Extracting key concepts for rubric generation"
    
    chat = LLM.chat
    chat.add_message(role: "system", content: CONCEPT_EXTRACTION_PROMPT)
    chat.add_message(role: "user", content: "Extract key concepts from this course summary:\n\n#{summary.content}")
    result = chat.complete
    response = result.content
    
    if response && response.strip.present?
      parse_concepts_response(response)
    else
      add_error("Failed to extract concepts from summary")
      []
    end
  rescue StandardError => e
    add_error("Concept extraction failed: #{e.message}")
    Rails.logger.error "Concept extraction error: #{e.message}"
    []
  end
  
  def build_concept_extraction_prompt
    <<~PROMPT
      You are an educational assessment expert. Your task is to analyze course material summaries and identify the key learning concepts that should be assessed.

      For each concept you identify, provide:
      1. **Concept Name**: A clear, concise name (2-5 words)
      2. **Description**: A brief description of what this concept encompasses
      3. **Assessment Focus**: What specifically should be evaluated for this concept

      Return your response in this exact JSON format:
      [
        {
          "name": "Concept Name",
          "description": "Brief description of the concept",
          "assessment_focus": "What should be assessed about this concept"
        }
      ]

      Guidelines:
      - Identify 3-7 key concepts maximum
      - Focus on concepts that can be meaningfully assessed through conversation
      - Ensure concepts are distinct and non-overlapping  
      - Prioritize fundamental concepts over minor details
      - Consider concepts that build upon each other
      
      Return only the JSON array, no additional text.
    PROMPT
  end
  
  def parse_concepts_response(response)
    begin
      # Clean the response to extract JSON
      json_match = response.match(/\[.*\]/m)
      return [] unless json_match
      
      concepts_data = JSON.parse(json_match[0])
      
      # Validate and clean the concepts
      valid_concepts = concepts_data.select do |concept|
        concept.is_a?(Hash) && 
        concept['name'].present? && 
        concept['description'].present? &&
        concept['assessment_focus'].present?
      end
      
      Rails.logger.info "Extracted #{valid_concepts.size} valid concepts"
      valid_concepts
      
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse concepts JSON: #{e.message}"
      Rails.logger.error "Response was: #{response}"
      add_error("Failed to parse extracted concepts")
      []
    end
  end
  
  def generate_concept_rubric(concept_info)
    # Generate detailed rubric levels for this concept
    messages = [
      {
        role: "system",
        content: build_rubric_generation_prompt
      },
      {
        role: "user",
        content: build_rubric_user_prompt(concept_info)
      }
    ]
    
    Rails.logger.info "Generating rubric for concept: #{concept_info['name']}"
    
    chat = LLM.chat
    chat.add_message(role: "system", content: build_rubric_generation_prompt)
    chat.add_message(role: "user", content: build_rubric_user_prompt(concept_info))
    result = chat.complete
    response = result.content
    
    if response && response.strip.present?
      rubric_levels = parse_rubric_response(response)
      if rubric_levels
        create_rubric_record(concept_info['name'], rubric_levels)
      else
        Rails.logger.error "Failed to parse rubric levels for concept: #{concept_info['name']}"
        nil
      end
    else
      add_error("Failed to generate rubric for concept: #{concept_info['name']}")
      nil
    end
  rescue StandardError => e
    add_error("Rubric generation failed for concept #{concept_info['name']}: #{e.message}")
    Rails.logger.error "Rubric generation error for #{concept_info['name']}: #{e.message}"
    nil
  end
  
  def build_rubric_generation_prompt
    <<~PROMPT
      You are an educational assessment specialist. Create detailed assessment rubrics with four proficiency levels for learning concepts.

      For each concept, define what constitutes performance at each level:
      
      **Beginner**: Student shows initial awareness but significant gaps
      **Developing**: Student demonstrates partial understanding with some misconceptions  
      **Proficient**: Student shows solid understanding with minor gaps
      **Mastery**: Student demonstrates comprehensive understanding and can apply/extend

      Return your response in this exact JSON format:
      {
        "beginner": "Clear description of beginner-level understanding and typical responses",
        "developing": "Clear description of developing-level understanding and typical responses", 
        "proficient": "Clear description of proficient-level understanding and typical responses",
        "mastery": "Clear description of mastery-level understanding and typical responses"
      }

      Guidelines:
      - Each level should be clearly distinguishable
      - Focus on observable behaviors and responses in conversation
      - Include typical misconceptions or correct applications at each level
      - Be specific enough to guide assessment decisions
      - Consider both conceptual understanding and practical application
      
      Return only the JSON object, no additional text.
    PROMPT
  end
  
  def build_rubric_user_prompt(concept_info)
    <<~PROMPT
      Create a detailed assessment rubric for this learning concept:

      **Concept**: #{concept_info['name']}
      **Description**: #{concept_info['description']}  
      **Assessment Focus**: #{concept_info['assessment_focus']}

      Generate the four proficiency levels (beginner, developing, proficient, mastery) that would help assess student understanding of this concept through conversational evaluation.
    PROMPT
  end
  
  def parse_rubric_response(response)
    begin
      # Clean the response to extract JSON
      json_match = response.match(/\{.*\}/m)
      return nil unless json_match
      
      levels = JSON.parse(json_match[0])
      
      # Validate required levels exist
      required_levels = %w[beginner developing proficient mastery]
      if required_levels.all? { |level| levels[level].present? }
        levels
      else
        Rails.logger.error "Missing required rubric levels. Got: #{levels.keys}"
        nil
      end
      
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse rubric JSON: #{e.message}"
      Rails.logger.error "Response was: #{response}"
      nil
    end
  end
  
  def create_rubric_record(concept_name, levels)
    rubric = course_material.rubrics.build(
      concept: concept_name,
      levels: levels
    )
    
    if rubric.save
      Rails.logger.info "Successfully created rubric for concept: #{concept_name}"
      rubric
    else
      add_error("Failed to save rubric for #{concept_name}: #{rubric.errors.full_messages.join(', ')}")
      Rails.logger.error "Rubric save failed: #{rubric.errors.full_messages.join(', ')}"
      nil
    end
  rescue StandardError => e
    add_error("Failed to create rubric for #{concept_name}: #{e.message}")
    Rails.logger.error "Rubric creation error: #{e.message}"
    nil
  end
  
  def add_error(message)
    @errors << message
  end
end
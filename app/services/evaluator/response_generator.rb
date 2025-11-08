# RAG-based evaluator service for generating contextual probing questions.
# Uses semantic similarity search and rubric-guided assessment to evaluate student understanding.
class Evaluator::ResponseGenerator
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :conversation_id, :integer
  attribute :student_message_id, :integer
  
  validates :conversation_id, presence: true
  validates :student_message_id, presence: true
  
  attr_reader :conversation, :student_message, :generated_response, :errors, :confidence_score
  
  def initialize(attributes = {})
    super
    @errors = []
    @generated_response = nil
    @confidence_score = 0.0
  end
  
  # Generate AI evaluator response to student message
  def generate!
    return false unless valid?
    
    load_conversation_data
    return false unless conversation && student_message
    
    begin
      # Retrieve relevant context using RAG
      context_data = retrieve_relevant_context
      return false if context_data[:chunks].empty?
      
      # Generate response using LLM with context and rubrics
      response_content = generate_contextual_response(context_data)
      return false unless response_content
      
      # Calculate confidence score
      @confidence_score = calculate_confidence_score(context_data, response_content)
      
      # Create and save AI response message
      ai_message = create_ai_message(response_content)
      return false unless ai_message
      
      @generated_response = ai_message
      
      Rails.logger.info "Generated evaluator response for conversation #{conversation_id} with confidence #{confidence_score}"
      true
      
    rescue StandardError => e
      add_error("Response generation failed: #{e.message}")
      Rails.logger.error "Evaluator response error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  # Get response generation summary
  def generation_summary
    {
      conversation_id: conversation_id,
      student_message_id: student_message_id,
      response_generated: generated_response.present?,
      confidence_score: confidence_score,
      success: errors.empty?,
      errors: errors
    }
  end
  
  private
  
  def load_conversation_data
    @conversation = Conversation.includes(:student, :course_material, :messages).find_by(id: conversation_id)
    unless @conversation
      add_error("Conversation not found with id: #{conversation_id}")
      return false
    end
    
    @student_message = @conversation.messages.find_by(id: student_message_id)
    unless @student_message
      add_error("Student message not found with id: #{student_message_id}")
      return false
    end
    
    unless @student_message.from_user?
      add_error("Message must be from user to generate AI response")
      return false
    end
    
    true
  end
  
  def retrieve_relevant_context
    course_material = conversation.course_material
    
    # Generate embedding for student's message
    query_embedding = generate_message_embedding(student_message.content)
    return { chunks: [], rubrics: [] } unless query_embedding
    
    # Find semantically similar chunks
    similar_chunks = find_similar_chunks(course_material, query_embedding)
    
    # Get relevant rubrics
    relevant_rubrics = get_relevant_rubrics(course_material, student_message.content)
    
    # Get conversation history
    conversation_history = get_conversation_history
    
    {
      chunks: similar_chunks,
      rubrics: relevant_rubrics,
      history: conversation_history,
      query_embedding: query_embedding
    }
  end
  
  def generate_message_embedding(text)
    begin
      LLM.embed(text)
    rescue StandardError => e
      Rails.logger.error "Failed to generate embedding: #{e.message}"
      add_error("Failed to generate embedding for message")
      nil
    end
  end
  
  def find_similar_chunks(course_material, query_embedding, limit: 5)
    return [] unless query_embedding
    
    # Convert embedding array to PostgreSQL vector format for pgvector
    embedding_string = "[#{query_embedding.join(',')}]"
    
    course_material.chunks
                   .select("id, text, course_material_id, embedding <=> '#{embedding_string}' AS similarity")
                   .order('similarity ASC')
                   .limit(limit)
  rescue StandardError => e
    Rails.logger.error "Similarity search failed: #{e.message}"
    []
  end
  
  def get_relevant_rubrics(course_material, message_content)
    # Get all rubrics for basic relevance, could be enhanced with semantic matching
    rubrics = course_material.rubrics.includes(:course_material)
    
    # Simple keyword matching for rubric relevance
    message_words = message_content.downcase.split(/\W+/)
    
    scored_rubrics = rubrics.map do |rubric|
      concept_words = rubric.concept.downcase.split(/\W+/)
      overlap_score = (message_words & concept_words).size
      
      { rubric: rubric, relevance_score: overlap_score }
    end
    
    # Return top relevant rubrics
    scored_rubrics.sort_by { |item| -item[:relevance_score] }
                  .take(3)
                  .map { |item| item[:rubric] }
  end
  
  def get_conversation_history(limit: 6)
    conversation.messages
               .where.not(id: student_message.id)
               .order(:created_at)
               .limit(limit)
               .map(&:to_llm_message)
  end
  
  def generate_contextual_response(context_data)
    messages = build_llm_messages(context_data)
    
    Rails.logger.info "Generating evaluator response using #{context_data[:chunks].size} chunks and #{context_data[:rubrics].size} rubrics"
    
    response = LLM.chat(messages: messages)
    
    if response && response.strip.present?
      response.strip
    else
      add_error("Empty response from LLM")
      nil
    end
  rescue StandardError => e
    add_error("LLM communication failed: #{e.message}")
    Rails.logger.error "LLM error in evaluator response: #{e.message}"
    nil
  end
  
  def build_llm_messages(context_data)
    messages = [
      {
        role: "system",
        content: build_evaluator_system_prompt(context_data)
      }
    ]
    
    # Add conversation history
    messages.concat(context_data[:history]) if context_data[:history].any?
    
    # Add current student message
    messages << student_message.to_llm_message
    
    messages
  end
  
  def build_evaluator_system_prompt(context_data)
    chunks_context = context_data[:chunks].map.with_index do |chunk, index|
      "Context #{index + 1}: #{chunk.text.strip}"
    end.join("\n\n")
    
    rubrics_context = context_data[:rubrics].map do |rubric|
      levels_summary = rubric.levels.map { |level, desc| "#{level.capitalize}: #{desc.truncate(100)}" }.join("; ")
      "#{rubric.concept}: #{levels_summary}"
    end.join("\n")
    
    <<~PROMPT
      You are an expert AI educational evaluator. Your role is to assess student understanding through Socratic dialogue, NOT to teach or provide answers.

      ## Your Objectives:
      1. **Probe Understanding**: Ask questions that reveal the depth of student knowledge
      2. **Identify Misconceptions**: Detect gaps or errors in reasoning
      3. **Assess Proficiency**: Determine student level according to rubrics
      4. **Guide Discovery**: Help students articulate their thinking without giving answers

      ## Assessment Context:
      **Course Material Content:**
      #{chunks_context}

      **Assessment Rubrics:**
      #{rubrics_context}

      ## Response Guidelines:
      - Ask ONE focused, probing question at a time
      - Build on student's previous responses
      - Use Socratic method: guide discovery through questions
      - Avoid lecturing or providing direct explanations
      - If student shows misconceptions, probe deeper to understand their reasoning
      - Reference course material implicitly through your questions
      - Keep responses conversational and encouraging
      - Aim for 2-3 sentences maximum

      ## Question Types to Use:
      - Clarification: "What do you mean when you say..."
      - Assumptions: "What assumptions are you making about..."
      - Evidence: "What evidence supports that view..."
      - Perspective: "How might someone who disagrees respond..."
      - Implications: "If that's true, what follows..."
      - Meta-questions: "How did you arrive at that conclusion..."

      Remember: Your goal is ASSESSMENT through dialogue, not teaching. Let the student do the thinking.
    PROMPT
  end
  
  def calculate_confidence_score(context_data, response_content)
    # Simple confidence calculation based on context quality and response characteristics
    base_score = 0.5
    
    # Factor in chunk similarity (lower similarity distance = higher confidence)
    if context_data[:chunks].any?
      avg_similarity = context_data[:chunks].sum { |chunk| chunk.similarity.to_f } / context_data[:chunks].size
      # Convert similarity distance to confidence (0.0-1.0 distance becomes 1.0-0.0 confidence)
      similarity_factor = [1.0 - avg_similarity, 0.0].max * 0.3
      base_score += similarity_factor
    end
    
    # Factor in rubric relevance
    if context_data[:rubrics].any?
      rubric_factor = 0.2
      base_score += rubric_factor
    end
    
    # Factor in response quality (length, question marks indicating probing questions)
    if response_content
      has_questions = response_content.include?('?')
      appropriate_length = response_content.length.between?(50, 300)
      
      base_score += 0.1 if has_questions
      base_score += 0.1 if appropriate_length
    end
    
    # Ensure score is between 0.0 and 1.0
    [[base_score, 1.0].min, 0.0].max.round(2)
  end
  
  def create_ai_message(content)
    ai_message = conversation.messages.build(
      role: "assistant",
      content: content
    )
    
    if ai_message.save
      Rails.logger.info "Created AI response message for conversation #{conversation_id}"
      ai_message
    else
      ai_message.errors.full_messages.each { |error| add_error(error) }
      Rails.logger.error "Failed to save AI message: #{ai_message.errors.full_messages.join(', ')}"
      nil
    end
  rescue StandardError => e
    add_error("Failed to create AI message: #{e.message}")
    Rails.logger.error "AI message creation error: #{e.message}"
    nil
  end
  
  def add_error(message)
    @errors << message
  end
end
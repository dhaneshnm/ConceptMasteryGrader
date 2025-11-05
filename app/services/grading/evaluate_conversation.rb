# Service for evaluating student conversations against rubrics and generating detailed reports.
# Analyzes message content, identifies concept mastery, and produces grading feedback.
class Grading::EvaluateConversation
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :conversation_id, :integer
  
  validates :conversation_id, presence: true
  
  attr_reader :conversation, :evaluation_results, :grade_report, :errors
  
  def initialize(attributes = {})
    super
    @errors = []
    @evaluation_results = {}
    @grade_report = nil
  end
  
  # Evaluate conversation and generate comprehensive grade report
  def evaluate!
    return false unless valid?
    
    load_conversation_data
    return false unless conversation
    
    begin
      Rails.logger.info "Starting conversation evaluation for ID: #{conversation_id}"
      
      # Analyze conversation content
      conversation_analysis = analyze_conversation_content
      return false unless conversation_analysis
      
      # Evaluate each rubric concept
      concept_evaluations = evaluate_rubric_concepts(conversation_analysis)
      return false unless concept_evaluations.any?
      
      # Generate overall assessment
      overall_assessment = generate_overall_assessment(concept_evaluations)
      
      # Create grade report
      @grade_report = create_grade_report(concept_evaluations, overall_assessment, conversation_analysis)
      return false unless @grade_report
      
      @evaluation_results = {
        conversation_id: conversation_id,
        concepts_evaluated: concept_evaluations.size,
        overall_score: calculate_overall_score(concept_evaluations),
        grade_report_id: @grade_report.id,
        evaluation_summary: overall_assessment[:summary]
      }
      
      Rails.logger.info "Conversation evaluation completed successfully: #{@evaluation_results}"
      true
      
    rescue StandardError => e
      add_error("Evaluation failed: #{e.message}")
      Rails.logger.error "Conversation evaluation error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  # Get evaluation summary
  def evaluation_summary
    {
      conversation_id: conversation_id,
      evaluation_completed: grade_report.present?,
      results: evaluation_results,
      success: errors.empty?,
      errors: errors
    }
  end
  
  private
  
  def load_conversation_data
    @conversation = Conversation.includes(:student, :course_material, :messages, course_material: :rubrics).find_by(id: conversation_id)
    
    unless @conversation
      add_error("Conversation not found with id: #{conversation_id}")
      return false
    end
    
    unless @conversation.messages.any?
      add_error("No messages found in conversation to evaluate")
      return false
    end
    
    unless @conversation.course_material.rubrics.any?
      add_error("No rubrics found for course material - cannot evaluate")
      return false
    end
    
    true
  end
  
  def analyze_conversation_content
    user_messages = conversation.messages.from_user.chronological
    ai_messages = conversation.messages.from_assistant.chronological
    
    return nil if user_messages.empty?
    
    # Extract key themes and concepts from user responses
    content_analysis = extract_content_themes(user_messages)
    
    # Analyze progression and understanding development
    progression_analysis = analyze_understanding_progression(user_messages)
    
    # Identify misconceptions or knowledge gaps
    misconception_analysis = identify_misconceptions(user_messages, ai_messages)
    
    {
      total_user_messages: user_messages.count,
      total_ai_messages: ai_messages.count,
      content_themes: content_analysis,
      progression: progression_analysis,
      misconceptions: misconception_analysis,
      conversation_length: user_messages.sum { |msg| msg.content.length }
    }
  rescue StandardError => e
    add_error("Content analysis failed: #{e.message}")
    Rails.logger.error "Content analysis error: #{e.message}"
    nil
  end
  
  def extract_content_themes(user_messages)
    # Combine all user message content
    combined_content = user_messages.map(&:content).join(" ")
    
    # Use LLM to extract key themes and concepts
    theme_prompt = build_theme_extraction_prompt(combined_content)
    
    response = LLM.chat(messages: [{ role: "user", content: theme_prompt }])
    
    if response&.strip&.present?
      # Parse LLM response to extract structured themes
      parse_theme_response(response)
    else
      { themes: [], key_concepts: [], confidence: 0.0 }
    end
  rescue StandardError => e
    Rails.logger.error "Theme extraction failed: #{e.message}"
    { themes: [], key_concepts: [], confidence: 0.0 }
  end
  
  def analyze_understanding_progression(user_messages)
    return { progression_score: 0.0, trend: "insufficient_data" } if user_messages.count < 2
    
    # Analyze progression through message complexity and depth
    message_scores = user_messages.map.with_index do |message, index|
      complexity_score = calculate_message_complexity(message.content)
      depth_score = calculate_conceptual_depth(message.content)
      
      {
        message_index: index,
        complexity: complexity_score,
        depth: depth_score,
        combined_score: (complexity_score + depth_score) / 2.0
      }
    end
    
    # Calculate trend
    early_avg = message_scores.first(message_scores.size / 2).sum { |s| s[:combined_score] } / (message_scores.size / 2.0)
    late_avg = message_scores.last(message_scores.size / 2).sum { |s| s[:combined_score] } / (message_scores.size / 2.0)
    
    progression_score = late_avg - early_avg
    trend = determine_progression_trend(progression_score)
    
    {
      progression_score: progression_score.round(2),
      trend: trend,
      message_scores: message_scores,
      early_average: early_avg.round(2),
      late_average: late_avg.round(2)
    }
  end
  
  def identify_misconceptions(user_messages, ai_messages)
    # Look for patterns that indicate misconceptions
    misconception_indicators = []
    
    # Check if AI repeatedly asks similar clarifying questions
    ai_questions = ai_messages.select { |msg| msg.content.include?("?") }
    repeated_themes = find_repeated_question_themes(ai_questions)
    
    # Check for common misconception patterns from database
    known_misconceptions = conversation.course_material.misconception_patterns
    matched_misconceptions = match_misconception_patterns(user_messages, known_misconceptions)
    
    {
      repeated_themes: repeated_themes,
      matched_patterns: matched_misconceptions,
      misconception_count: repeated_themes.size + matched_misconceptions.size
    }
  end
  
  def evaluate_rubric_concepts(conversation_analysis)
    rubrics = conversation.course_material.rubrics
    concept_evaluations = {}
    
    rubrics.each do |rubric|
      evaluation = evaluate_single_concept(rubric, conversation_analysis)
      concept_evaluations[rubric.concept] = evaluation if evaluation
    end
    
    concept_evaluations
  end
  
  def evaluate_single_concept(rubric, conversation_analysis)
    # Analyze user messages for evidence of concept understanding
    user_messages = conversation.messages.from_user.chronological
    concept_evidence = find_concept_evidence(user_messages, rubric)
    
    # Use LLM to evaluate against rubric levels
    evaluation_prompt = build_concept_evaluation_prompt(rubric, concept_evidence, conversation_analysis)
    
    response = LLM.chat(messages: [{ role: "user", content: evaluation_prompt }])
    
    if response&.strip&.present?
      parse_concept_evaluation(response, rubric)
    else
      add_error("Failed to evaluate concept: #{rubric.concept}")
      nil
    end
  rescue StandardError => e
    add_error("Concept evaluation failed for #{rubric.concept}: #{e.message}")
    Rails.logger.error "Concept evaluation error: #{e.message}"
    nil
  end
  
  def find_concept_evidence(user_messages, rubric)
    concept_keywords = extract_concept_keywords(rubric.concept)
    
    relevant_messages = user_messages.select do |message|
      content_words = message.content.downcase.split(/\W+/)
      (content_words & concept_keywords).any?
    end
    
    {
      relevant_messages: relevant_messages.map(&:content),
      evidence_strength: relevant_messages.size,
      total_evidence_length: relevant_messages.sum { |msg| msg.content.length }
    }
  end
  
  def generate_overall_assessment(concept_evaluations)
    return { summary: "No concepts evaluated", recommendations: [] } if concept_evaluations.empty?
    
    # Calculate overall metrics
    avg_score = concept_evaluations.values.sum { |eval| eval[:score] } / concept_evaluations.size.to_f
    strengths = concept_evaluations.select { |_, eval| eval[:score] >= 0.7 }.keys
    weaknesses = concept_evaluations.select { |_, eval| eval[:score] < 0.5 }.keys
    
    # Generate summary and recommendations
    summary = generate_assessment_summary(avg_score, strengths, weaknesses)
    recommendations = generate_learning_recommendations(weaknesses, concept_evaluations)
    
    {
      overall_score: avg_score.round(2),
      summary: summary,
      recommendations: recommendations,
      strengths: strengths,
      areas_for_improvement: weaknesses
    }
  end
  
  def create_grade_report(concept_evaluations, overall_assessment, conversation_analysis)
    # Build detailed scores hash
    detailed_scores = concept_evaluations.transform_values do |evaluation|
      {
        score: evaluation[:score],
        level: evaluation[:level],
        evidence: evaluation[:evidence],
        feedback: evaluation[:feedback]
      }
    end
    
    # Create grade report record
    report = conversation.build_grade_report(
      overall_score: overall_assessment[:overall_score],
      detailed_scores: detailed_scores,
      feedback: generate_comprehensive_feedback(overall_assessment, conversation_analysis),
      recommendations: overall_assessment[:recommendations],
      evaluated_at: Time.current
    )
    
    if report.save
      Rails.logger.info "Created grade report #{report.id} for conversation #{conversation_id}"
      report
    else
      report.errors.full_messages.each { |error| add_error(error) }
      Rails.logger.error "Failed to create grade report: #{report.errors.full_messages.join(', ')}"
      nil
    end
  rescue StandardError => e
    add_error("Grade report creation failed: #{e.message}")
    Rails.logger.error "Grade report creation error: #{e.message}"
    nil
  end
  
  # Helper methods for text analysis and scoring
  
  def calculate_message_complexity(content)
    # Simple complexity scoring based on length, vocabulary, and sentence structure
    word_count = content.split.size
    unique_words = content.downcase.split(/\W+/).uniq.size
    sentence_count = content.split(/[.!?]+/).size
    
    complexity = (unique_words / word_count.to_f) + (word_count / sentence_count.to_f) / 10.0
    [complexity, 1.0].min
  end
  
  def calculate_conceptual_depth(content)
    # Score based on use of technical terms, explanations, and reasoning
    depth_indicators = %w[because therefore however although since thus hence consequently]
    technical_patterns = [/\w{8,}/, /[A-Z]{2,}/, /\d+\.\d+/]
    
    depth_score = 0.0
    depth_score += depth_indicators.count { |word| content.downcase.include?(word) } * 0.1
    depth_score += technical_patterns.count { |pattern| content.match?(pattern) } * 0.15
    depth_score += (content.length / 100.0) * 0.05
    
    [depth_score, 1.0].min
  end
  
  def determine_progression_trend(progression_score)
    case progression_score
    when 0.3..Float::INFINITY then "strong_improvement"
    when 0.1..0.3 then "moderate_improvement"
    when -0.1..0.1 then "stable"
    when -0.3..-0.1 then "slight_decline"
    else "concerning_decline"
    end
  end
  
  def extract_concept_keywords(concept)
    concept.downcase.split(/\W+/).reject { |word| word.length < 3 }
  end
  
  def calculate_overall_score(concept_evaluations)
    return 0.0 if concept_evaluations.empty?
    concept_evaluations.values.sum { |eval| eval[:score] } / concept_evaluations.size.to_f
  end
  
  # LLM prompt builders and response parsers
  
  def build_theme_extraction_prompt(content)
    <<~PROMPT
      Analyze this student's responses and identify key themes and concepts discussed:

      STUDENT RESPONSES:
      #{content.truncate(2000)}

      Please provide a JSON response with:
      - themes: Array of 3-5 main themes/topics
      - key_concepts: Array of specific concepts mentioned
      - confidence: Float 0.0-1.0 indicating analysis confidence

      Format: {"themes": [...], "key_concepts": [...], "confidence": 0.85}
    PROMPT
  end
  
  def build_concept_evaluation_prompt(rubric, evidence, conversation_analysis)
    levels_description = rubric.levels.map { |level, desc| "#{level.upcase}: #{desc}" }.join("\n")
    
    <<~PROMPT
      Evaluate student understanding of "#{rubric.concept}" based on their conversation responses.

      RUBRIC LEVELS:
      #{levels_description}

      STUDENT EVIDENCE:
      #{evidence[:relevant_messages].join("\n\n")}

      CONVERSATION CONTEXT:
      - Total messages: #{conversation_analysis[:total_user_messages]}
      - Progression trend: #{conversation_analysis[:progression][:trend]}
      - Evidence strength: #{evidence[:evidence_strength]} relevant messages

      Provide JSON evaluation:
      {
        "level": "novice|developing|proficient|advanced",
        "score": 0.75,
        "evidence": "Key evidence from responses...",
        "feedback": "Specific feedback on understanding...",
        "confidence": 0.80
      }
    PROMPT
  end
  
  def parse_theme_response(response)
    parsed = JSON.parse(response.strip)
    {
      themes: parsed["themes"] || [],
      key_concepts: parsed["key_concepts"] || [],
      confidence: parsed["confidence"] || 0.0
    }
  rescue JSON::ParserError
    { themes: [], key_concepts: [], confidence: 0.0 }
  end
  
  def parse_concept_evaluation(response, rubric)
    parsed = JSON.parse(response.strip)
    
    {
      rubric_id: rubric.id,
      concept: rubric.concept,
      level: parsed["level"],
      score: convert_level_to_score(parsed["level"]),
      evidence: parsed["evidence"],
      feedback: parsed["feedback"],
      confidence: parsed["confidence"] || 0.0
    }
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse concept evaluation: #{e.message}"
    {
      rubric_id: rubric.id,
      concept: rubric.concept,
      level: "novice",
      score: 0.25,
      evidence: "Unable to parse evaluation",
      feedback: "Evaluation parsing failed",
      confidence: 0.0
    }
  end
  
  def convert_level_to_score(level)
    case level&.downcase
    when "advanced" then 0.95
    when "proficient" then 0.75
    when "developing" then 0.55
    when "novice" then 0.25
    else 0.0
    end
  end
  
  def generate_assessment_summary(avg_score, strengths, weaknesses)
    performance_level = case avg_score
                       when 0.8..1.0 then "excellent"
                       when 0.6..0.8 then "good"
                       when 0.4..0.6 then "fair"
                       else "needs improvement"
                       end
    
    summary = "Overall performance: #{performance_level} (#{(avg_score * 100).round}%)."
    
    if strengths.any?
      summary += " Strong understanding demonstrated in: #{strengths.join(', ')}."
    end
    
    if weaknesses.any?
      summary += " Areas needing attention: #{weaknesses.join(', ')}."
    end
    
    summary
  end
  
  def generate_learning_recommendations(weaknesses, concept_evaluations)
    recommendations = []
    
    weaknesses.each do |concept|
      evaluation = concept_evaluations[concept]
      if evaluation && evaluation[:feedback]
        recommendations << "#{concept}: #{evaluation[:feedback]}"
      end
    end
    
    # Add general recommendations based on overall patterns
    if weaknesses.size > concept_evaluations.size / 2
      recommendations << "Consider reviewing foundational concepts before advancing to new material."
    end
    
    recommendations
  end
  
  def generate_comprehensive_feedback(overall_assessment, conversation_analysis)
    feedback_parts = []
    
    feedback_parts << overall_assessment[:summary]
    
    if conversation_analysis[:progression][:trend] == "strong_improvement"
      feedback_parts << "Great progress shown throughout the conversation!"
    elsif conversation_analysis[:progression][:trend] == "concerning_decline"
      feedback_parts << "Consider taking a break and reviewing earlier concepts."
    end
    
    if conversation_analysis[:misconceptions][:misconception_count] > 0
      feedback_parts << "Some conceptual areas may benefit from additional clarification."
    end
    
    feedback_parts.join(" ")
  end
  
  def find_repeated_question_themes(ai_questions)
    # Simplified implementation - could be enhanced with semantic similarity
    question_themes = ai_questions.map { |msg| extract_question_theme(msg.content) }
    question_themes.group_by(&:itself).select { |_, occurrences| occurrences.size > 1 }.keys
  end
  
  def extract_question_theme(question)
    # Extract key words from questions to identify themes
    words = question.downcase.split(/\W+/)
    theme_words = words.select { |word| word.length > 4 }.first(2)
    theme_words.join("_")
  end
  
  def match_misconception_patterns(user_messages, known_misconceptions)
    matched = []
    
    known_misconceptions.each do |pattern|
      user_messages.each do |message|
        if message.content.downcase.include?(pattern.pattern.downcase)
          matched << {
            pattern_id: pattern.id,
            description: pattern.description,
            matched_in: message.content.truncate(100)
          }
        end
      end
    end
    
    matched
  end
  
  def add_error(message)
    @errors << message
  end
end
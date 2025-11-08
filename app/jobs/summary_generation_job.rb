# Background job for generating course material summaries.
# Uses RAG to analyze chunks and create structured summaries via LLM.
class SummaryGenerationJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 10.seconds, attempts: 3
  
  # Generate summary for a course material
  def perform(course_material_id)
    Rails.logger.info "Starting summary generation for course material #{course_material_id}"
    
    service = Summaries::Generate.new(course_material_id: course_material_id)
    
    if service.generate!
      Rails.logger.info "Successfully completed summary generation for course material #{course_material_id}"
      Rails.logger.info "Generation summary: #{service.generation_summary}"
    else
      Rails.logger.error "Summary generation failed for course material #{course_material_id}"
      Rails.logger.error "Errors: #{service.errors.join(', ')}"
      raise StandardError, "Summary generation failed: #{service.errors.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Summary generation job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
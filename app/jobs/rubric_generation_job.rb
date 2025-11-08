# Background job for generating assessment rubrics.
# Creates detailed rubrics with proficiency levels for each key concept.
class RubricGenerationJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 15.seconds, attempts: 3
  
  # Generate rubrics for a course material
  def perform(course_material_id)
    Rails.logger.info "Starting rubric generation for course material #{course_material_id}"
    
    service = Rubrics::Generate.new(course_material_id: course_material_id)
    
    if service.generate!
      Rails.logger.info "Successfully completed rubric generation for course material #{course_material_id}"
      Rails.logger.info "Generation summary: #{service.generation_summary}"
    else
      Rails.logger.error "Rubric generation failed for course material #{course_material_id}"
      Rails.logger.error "Errors: #{service.errors.join(', ')}"
      raise StandardError, "Rubric generation failed: #{service.errors.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Rubric generation job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
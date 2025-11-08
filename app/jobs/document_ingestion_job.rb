# Background job for processing course material PDFs.
# Handles text extraction, chunking, and embedding generation asynchronously.
class DocumentIngestionJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  # Process a course material document
  def perform(course_material_id)
    Rails.logger.info "Starting document ingestion for course material #{course_material_id}"
    
    service = Documents::IngestionService.new(course_material_id: course_material_id)
    
    if service.process!
      Rails.logger.info "Successfully completed document ingestion for course material #{course_material_id}"
      Rails.logger.info "Processing summary: #{service.processing_summary}"
    else
      Rails.logger.error "Document ingestion failed for course material #{course_material_id}"
      Rails.logger.error "Errors: #{service.errors.join(', ')}"
      raise StandardError, "Document ingestion failed: #{service.errors.join(', ')}"
    end
  rescue StandardError => e
    Rails.logger.error "Document ingestion job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
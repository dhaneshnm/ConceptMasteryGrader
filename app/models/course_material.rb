# CourseMaterial represents uploaded educational content that can be processed and analyzed.
# It serves as the root entity for all RAG operations including chunking, summarization, and rubric generation.
class CourseMaterial < ApplicationRecord
  # Status enum for processing workflow
  enum :status, { uploaded: 0, processed: 1 }, default: :uploaded
  
  # ActiveStorage association for file uploads
  has_many_attached :files
  
  # Associated domain objects
  has_many :chunks, dependent: :destroy
  has_one :summary, dependent: :destroy
  has_many :rubrics, dependent: :destroy
  has_many :misconception_patterns, dependent: :destroy
  has_many :conversations, dependent: :destroy
  
  # Validations
  validates :title, presence: true, length: { minimum: 1, maximum: 255 }
  validates :files, presence: true, on: :create
  validate :files_are_pdfs, if: -> { files.attached? }
  
  scope :processed, -> { where(status: :processed) }
  scope :uploaded, -> { where(status: :uploaded) }
  
  # Callbacks
  after_create :enqueue_processing_job, if: :files_attached?
  
  # Mark as processed after successful ingestion
  def mark_as_processed!
    update!(status: :processed)
  end
  
  # Check if files are attached
  def files_attached?
    files.attached? && files.any?
  end
  
  # Enqueue background job for processing
  def enqueue_processing_job
    DocumentIngestionJob.perform_later(id)
  end
  
  # Generate JSON data for dashboard display
  def to_dashboard_json
    {
      id: id,
      title: title,
      conversation_count: conversations.count,
      evaluated_conversation_count: conversations.joins(:grade_reports).distinct.count,
      summary_count: summary ? 1 : 0,
      rubric_count: rubrics.count,
      recent_activity_count: conversations.where(updated_at: 1.week.ago..).count,
      last_updated: updated_at.iso8601
    }
  end
  
  private
  
  def files_are_pdfs
    return unless files.attached?
    
    files.each_with_index do |file, index|
      unless file.content_type == 'application/pdf'
        errors.add(:files, "File #{index + 1} (#{file.filename}) must be a PDF file")
      end
    end
  end
end

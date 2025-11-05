# Conversation represents an interactive dialogue session between a student and the AI evaluator.
# Contains messages and tracks the evaluation context for a specific course material.
class Conversation < ApplicationRecord
  belongs_to :student
  belongs_to :course_material
  
  # Associated records
  has_many :messages, dependent: :destroy, inverse_of: :conversation
  has_many :grade_reports, dependent: :destroy
  
  # Validations
  validates :student, presence: true
  validates :course_material, presence: true
  
  # Scopes
  scope :recent, -> { order(updated_at: :desc) }
  scope :with_messages, -> { includes(:messages) }
  
  # Get messages in chronological order
  def ordered_messages
    messages.order(:created_at)
  end
  
  # Get student messages only
  def student_messages
    messages.where(role: 'user')
  end
  
  # Get system messages only
  def system_messages
    messages.where(role: 'assistant')
  end
  
  # Get the latest grade report
  def latest_grade_report
    grade_reports.order(:created_at).last
  end
  
  # Check if conversation needs grading
  def needs_grading?
    student_messages.exists? && grade_reports.empty?
  end
  
  # Generate JSON data for dashboard display
  def to_dashboard_json
    latest_report = grade_reports.order(created_at: :desc).first
    
    {
      id: id,
      student_name: student.name,
      student_email: student.email,
      course_material_title: course_material.title,
      message_count: messages.count,
      user_message_count: messages.from_user.count,
      last_activity: updated_at.iso8601,
      evaluated: grade_reports.any?,
      needs_attention: latest_report&.needs_attention? || false,
      grade_report: latest_report&.to_dashboard_json
    }
  end
end

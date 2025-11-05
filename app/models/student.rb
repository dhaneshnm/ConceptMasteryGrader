# Student represents a learner engaging with course materials through conversations.
# Tracks interactions and assessment results across multiple course materials.
class Student < ApplicationRecord
  # Associations
  has_many :conversations, dependent: :destroy
  has_many :course_materials, through: :conversations
  has_many :messages, through: :conversations
  has_many :grade_reports, through: :conversations
  
  # Validations
  validates :name, presence: true, length: { minimum: 1, maximum: 255 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  # Get conversations for a specific course material
  def conversations_for(course_material)
    conversations.where(course_material: course_material)
  end
  
  # Get latest grade report for a course material
  def latest_grade_for(course_material)
    conversations_for(course_material)
      .joins(:grade_reports)
      .includes(:grade_reports)
      .order('grade_reports.created_at DESC')
      .first&.grade_reports&.first
  end
end

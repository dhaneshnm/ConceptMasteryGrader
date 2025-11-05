# Message represents individual turns in a conversation between student and AI evaluator.
# Stores both user messages and system responses in the dialogue flow.
class Message < ApplicationRecord
  belongs_to :conversation
  
  # Valid roles for conversation participants
  VALID_ROLES = %w[user assistant system].freeze
  
  # Validations
  validates :role, presence: true, inclusion: { in: VALID_ROLES }
  validates :content, presence: true, length: { minimum: 1 }
  validates :conversation, presence: true
  
  # Scopes
  scope :user_messages, -> { where(role: 'user') }
  scope :assistant_messages, -> { where(role: 'assistant') }
  scope :system_messages, -> { where(role: 'system') }
  scope :chronological, -> { order(:created_at) }
  
  # Check if message is from student
  def from_user?
    role == 'user'
  end
  
  # Check if message is from AI assistant
  def from_assistant?
    role == 'assistant'
  end
  
  # Check if message is system message
  def from_system?
    role == 'system'
  end
  
  # Get formatted content for LLM API
  def to_llm_message
    {
      role: role,
      content: content
    }
  end
end
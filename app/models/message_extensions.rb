# Helper method to add LLM message format to Message model
class Message < ApplicationRecord
  belongs_to :conversation

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  scope :chronological, -> { order(:created_at) }
  scope :from_user, -> { where(role: "user") }
  scope :from_assistant, -> { where(role: "assistant") }

  # Check if message is from user
  def from_user?
    role == "user"
  end

  # Check if message is from AI assistant
  def from_assistant?
    role == "assistant"
  end

  # Convert message to LLM chat format
  def to_llm_message
    {
      role: role,
      content: content
    }
  end

  # Format content for display (could add markdown parsing later)
  def formatted_content
    content
  end

  # Get sender display name
  def sender_name
    case role
    when "user"
      conversation&.student&.name || "Student"
    when "assistant"
      "AI Tutor"
    else
      "Unknown"
    end
  end

  # Get CSS classes for message styling
  def message_classes
    base_classes = "message p-4 rounded-lg max-w-3xl"
    
    case role
    when "user"
      "#{base_classes} bg-blue-50 border border-blue-200 ml-auto"
    when "assistant"
      "#{base_classes} bg-gray-50 border border-gray-200 mr-auto"
    else
      "#{base_classes} bg-gray-100"
    end
  end
end
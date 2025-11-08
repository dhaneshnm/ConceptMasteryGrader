module ApplicationHelper
  # Message bubble styling based on message sender
  def message_bubble_class(message)
    if message.from_user?
      "bg-blue-600 text-white"
    else
      "bg-gray-100 text-gray-900"
    end
  end
  
  # Display name for message author
  def message_author_name(message)
    if message.from_user?
      message.conversation.student.name.split.first
    else
      "AI Evaluator"
    end
  end
  
  # Status badge styling
  def status_badge_class(status)
    case status.to_s
    when 'uploaded'
      'bg-yellow-100 text-yellow-800'
    when 'processed'
      'bg-green-100 text-green-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end

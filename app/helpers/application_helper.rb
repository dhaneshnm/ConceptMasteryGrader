module ApplicationHelper
  # Message bubble styling based on message sender
  def message_bubble_class(message)
    if message.from_user?
      "bg-primary-600 text-white"
    else
      "bg-neutral-100 text-neutral-800"
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
  
  # Status badge styling with green theme
  def status_badge_class(status)
    case status.to_s
    when 'uploaded'
      'bg-secondary-100 text-secondary-800'
    when 'processed'
      'bg-primary-100 text-primary-800'
    when 'processing'
      'bg-accent-100 text-accent-800'
    when 'error'
      'bg-red-100 text-red-800'
    else
      'bg-neutral-100 text-neutral-800'
    end
  end
  
  # Button classes for consistent styling
  def btn_primary_class
    "btn-primary btn-hover-lift"
  end
  
  def btn_secondary_class
    "btn-secondary btn-hover-lift"
  end
  
  def btn_outline_class
    "btn-outline"
  end
  
  # Alert message styling
  def alert_class(type)
    case type.to_s
    when 'success'
      'alert alert-success'
    when 'error', 'alert'
      'alert alert-error'
    when 'warning'
      'alert alert-warning'
    when 'notice', 'info'
      'alert alert-info'
    else
      'alert alert-info'
    end
  end
end

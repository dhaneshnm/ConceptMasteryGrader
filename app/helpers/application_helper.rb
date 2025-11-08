module ApplicationHelper
  # Message bubble styling based on message sender
  def message_bubble_class(message)
    if message.from_user?
      "bg-green-500 text-white shadow-sm"
    else
      "bg-white border border-neutral-200 text-neutral-800 shadow-sm"
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

  # Render markdown content as HTML
  def markdown(text)
    return '' if text.blank?
    
    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      no_images: false,
      no_links: false,
      no_styles: false,
      safe_links_only: true,
      with_toc_data: false,
      hard_wrap: true
    )
    
    markdown_processor = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      fenced_code_blocks: true,
      lax_spacing: true,
      no_intra_emphasis: true,
      strikethrough: true,
      superscript: true,
      tables: true
    )
    
    markdown_processor.render(text).html_safe
  end
end

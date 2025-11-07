module RubricsHelper
  def level_card_class(level)
    case level.to_s
    when 'beginner'
      'bg-red-50'
    when 'developing'
      'bg-yellow-50'
    when 'proficient'
      'bg-blue-50'
    when 'mastery'
      'bg-green-50'
    else
      'bg-gray-50'
    end
  end
  
  def level_border_class(level)
    case level.to_s
    when 'beginner'
      'border-red-200'
    when 'developing'
      'border-yellow-200'
    when 'proficient'
      'border-blue-200'
    when 'mastery'
      'border-green-200'
    else
      'border-gray-200'
    end
  end
  
  def level_text_class(level)
    case level.to_s
    when 'beginner'
      'text-red-900'
    when 'developing'
      'text-yellow-900'
    when 'proficient'
      'text-blue-900'
    when 'mastery'
      'text-green-900'
    else
      'text-gray-900'
    end
  end
  
  def level_description_class(level)
    case level.to_s
    when 'beginner'
      'text-red-700'
    when 'developing'
      'text-yellow-700'
    when 'proficient'
      'text-blue-700'
    when 'mastery'
      'text-green-700'
    else
      'text-gray-700'
    end
  end
end
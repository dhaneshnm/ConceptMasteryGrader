# Service for splitting text into semantically meaningful chunks for embedding generation.
# Aims for chunks of 200-500 tokens while preserving sentence and paragraph boundaries.
class Documents::TextChunker
  # Token count estimation (rough approximation: 1 token ≈ 4 characters)
  CHARS_PER_TOKEN = 4
  MIN_CHUNK_TOKENS = 200
  MAX_CHUNK_TOKENS = 500
  
  # Character limits based on token estimates
  MIN_CHUNK_CHARS = MIN_CHUNK_TOKENS * CHARS_PER_TOKEN  # ~800 chars
  MAX_CHUNK_CHARS = MAX_CHUNK_TOKENS * CHARS_PER_TOKEN  # ~2000 chars
  
  attr_reader :text, :chunks
  
  def initialize(text)
    @text = text
    @chunks = []
  end
  
  # Split text into chunks and return array of chunk strings
  def chunk!
    return [] if text.blank?
    
    paragraphs = split_into_paragraphs
    current_chunk = ""
    
    paragraphs.each do |paragraph|
      # If paragraph alone exceeds max size, split it further
      if paragraph.length > MAX_CHUNK_CHARS
        # Save current chunk if it has content
        save_chunk(current_chunk) if current_chunk.present?
        current_chunk = ""
        
        # Split large paragraph into sentences
        split_large_paragraph(paragraph)
      elsif (current_chunk.length + paragraph.length) > MAX_CHUNK_CHARS
        # Current chunk would exceed limit, save it and start new one
        save_chunk(current_chunk) if current_chunk.present?
        current_chunk = paragraph
      else
        # Add paragraph to current chunk
        current_chunk += current_chunk.present? ? "\n\n#{paragraph}" : paragraph
      end
    end
    
    # Save final chunk
    save_chunk(current_chunk) if current_chunk.present?
    
    chunks
  end
  
  # Get chunk count
  def chunk_count
    chunks.size
  end
  
  # Get estimated token count for all chunks
  def total_estimated_tokens
    chunks.sum { |chunk| estimate_tokens(chunk) }
  end
  
  private
  
  def split_into_paragraphs
    text.split(/\n\s*\n/)
        .map(&:strip)
        .reject(&:blank?)
  end
  
  def split_large_paragraph(paragraph)
    sentences = split_into_sentences(paragraph)
    current_chunk = ""
    
    sentences.each do |sentence|
      if sentence.length > MAX_CHUNK_CHARS
        # Individual sentence is too large, split by words
        save_chunk(current_chunk) if current_chunk.present?
        split_large_sentence(sentence)
        current_chunk = ""
      elsif (current_chunk.length + sentence.length) > MAX_CHUNK_CHARS
        save_chunk(current_chunk) if current_chunk.present?
        current_chunk = sentence
      else
        current_chunk += current_chunk.present? ? " #{sentence}" : sentence
      end
    end
    
    save_chunk(current_chunk) if current_chunk.present?
  end
  
  def split_into_sentences(text)
    # Simple sentence splitting - can be enhanced with NLP libraries
    text.split(/(?<=[.!?])\s+/)
        .map(&:strip)
        .reject(&:blank?)
  end
  
  def split_large_sentence(sentence)
    words = sentence.split(/\s+/)
    current_chunk = ""
    
    words.each do |word|
      if (current_chunk.length + word.length + 1) > MAX_CHUNK_CHARS
        save_chunk(current_chunk) if current_chunk.present?
        current_chunk = word
      else
        current_chunk += current_chunk.present? ? " #{word}" : word
      end
    end
    
    save_chunk(current_chunk) if current_chunk.present?
  end
  
  def save_chunk(chunk_text)
    cleaned_chunk = chunk_text.strip
    return if cleaned_chunk.blank?
    
    # Only save chunks that meet minimum size or are the only content available
    if cleaned_chunk.length >= MIN_CHUNK_CHARS || chunks.empty?
      chunks << cleaned_chunk
    elsif chunks.any?
      # Merge small chunk with the last chunk if possible
      last_chunk = chunks.last
      if (last_chunk.length + cleaned_chunk.length) <= MAX_CHUNK_CHARS
        chunks[-1] = "#{last_chunk}\n\n#{cleaned_chunk}"
      else
        chunks << cleaned_chunk  # Save anyway if can't merge
      end
    end
  end
  
  def estimate_tokens(text)
    (text.length / CHARS_PER_TOKEN.to_f).ceil
  end
end
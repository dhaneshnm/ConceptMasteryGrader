# Main service for processing uploaded course materials.
# Coordinates PDF extraction, text chunking, and embedding generation.
class Documents::IngestionService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :course_material_id, :integer
  
  validates :course_material_id, presence: true
  
  attr_reader :course_material, :errors, :processed_chunks
  
  def initialize(attributes = {})
    super
    @errors = []
    @processed_chunks = 0
  end
  
  # Process the course material: extract text from all files, chunk, and generate embeddings
  def process!
    return false unless valid?
    
    load_course_material
    return false unless course_material&.files&.attached?
    
    begin
      all_text_chunks = []
      
      # Process each uploaded file
      course_material.files.each_with_index do |file, index|
        Rails.logger.info "Processing file #{index + 1}/#{course_material.files.count}: #{file.filename}"
        
        # Extract text from PDF
        extracted_text = extract_pdf_text_from_file(file)
        next unless extracted_text
        
        # Split into chunks with file identifier
        chunks_data = create_text_chunks_from_file(extracted_text, file.filename.to_s, index)
        all_text_chunks.concat(chunks_data) if chunks_data.any?
      end
      
      return false if all_text_chunks.empty?
      
      # Generate embeddings and save chunks for all files
      save_chunks_with_embeddings(all_text_chunks)
      
      # Mark course material as processed
      course_material.mark_as_processed!
      
      true
    rescue StandardError => e
      add_error("Processing failed: #{e.message}")
      false
    end
  end
  
  # Get processing results summary
  def processing_summary
    {
      course_material_id: course_material_id,
      chunks_created: processed_chunks,
      success: errors.empty?,
      errors: errors
    }
  end
  
  private
  
  def load_course_material
    @course_material = CourseMaterial.find_by(id: course_material_id)
    unless @course_material
      add_error("Course material not found with id: #{course_material_id}")
      return false
    end
    
    unless @course_material.files.attached? && @course_material.files.any?
      add_error("No files attached to course material")
      return false
    end
    
    true
  end
  
  def extract_pdf_text_from_file(file)
    # Download the file temporarily for processing
    file.open do |tempfile|
      processor = Documents::PdfProcessor.new(tempfile.path)
      text = processor.extract_text
      
      unless processor.success?
        processor.errors.each { |error| add_error("#{file.filename}: #{error}") }
        return nil
      end
      
      text
    end
  rescue StandardError => e
    add_error("Failed to process PDF #{file.filename}: #{e.message}")
    nil
  end

  def extract_pdf_text
    # Deprecated - kept for backward compatibility
    # This method now processes the first file only
    return nil unless course_material.files.attached? && course_material.files.any?
    extract_pdf_text_from_file(course_material.files.first)
  end
  
  def create_text_chunks_from_file(text, filename, file_index)
    chunker = Documents::TextChunker.new(text)
    chunks = chunker.chunk!
    
    if chunks.empty?
      add_error("No chunks could be created from the text in #{filename}")
      return []
    end
    
    # Add file metadata to each chunk
    chunks_with_metadata = chunks.map.with_index do |chunk_text, chunk_index|
      {
        text: chunk_text,
        filename: filename,
        file_index: file_index,
        chunk_index: chunk_index
      }
    end
    
    Rails.logger.info "Created #{chunks.size} chunks from file #{filename} in course material #{course_material_id}"
    chunks_with_metadata
  end

  def create_text_chunks(text)
    # Deprecated - kept for backward compatibility
    chunker = Documents::TextChunker.new(text)
    chunks = chunker.chunk!
    
    if chunks.empty?
      add_error("No chunks could be created from the text")
      return []
    end
    
    Rails.logger.info "Created #{chunks.size} chunks from course material #{course_material_id}"
    chunks
  end
  
  def save_chunks_with_embeddings(chunks_data)
    chunks_data.each_with_index do |chunk_data, index|
      begin
        # Handle both old string format and new hash format for backward compatibility
        chunk_text = chunk_data.is_a?(Hash) ? chunk_data[:text] : chunk_data
        filename = chunk_data.is_a?(Hash) ? chunk_data[:filename] : "unknown"
        
        # Generate embedding using ruby_llm
        embedding = generate_embedding(chunk_text)
        next unless embedding
        
        # Create chunk record
        Chunk.create_with_embedding(
          course_material: course_material,
          text: chunk_text,
          embedding_array: embedding
        )
        
        @processed_chunks += 1
        
        Rails.logger.debug "Processed chunk #{index + 1}/#{chunks_data.size} from #{filename} for course material #{course_material_id}"
        
      rescue StandardError => e
        error_msg = chunk_data.is_a?(Hash) ? "#{chunk_data[:filename]} chunk #{index + 1}" : "chunk #{index + 1}"
        Rails.logger.error "Failed to process #{error_msg}: #{e.message}"
        add_error("Failed to process #{error_msg}: #{e.message}")
      end
    end
    
    if processed_chunks == 0
      add_error("No chunks were successfully processed")
      return false
    end
    
    Rails.logger.info "Successfully processed #{processed_chunks} chunks for course material #{course_material_id}"
    true
  end
  
  def generate_embedding(text)
    begin
      # Use ruby_llm to generate embedding
      embedding_result = LLM.embed(text)
      
      # Extract the actual embedding array from the RubyLLM::Embedding object
      # Try different common attribute names for embedding data
      if embedding_result.respond_to?(:vectors)
        embedding_result.vectors
      elsif embedding_result.respond_to?(:vector)
        embedding_result.vector
      elsif embedding_result.respond_to?(:embedding)
        embedding_result.embedding
      elsif embedding_result.respond_to?(:data)
        embedding_result.data
      elsif embedding_result.respond_to?(:to_a)
        embedding_result.to_a
      else
        Rails.logger.error "Unknown embedding format: #{embedding_result.class}. Available methods: #{embedding_result.methods.grep(/vector|embedding|data|array/).join(', ')}"
        add_error("Unknown embedding format: #{embedding_result.class}")
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Failed to generate embedding: #{e.message}"
      add_error("Failed to generate embedding: #{e.message}")
      nil
    end
  end
  
  def add_error(message)
    @errors << message
  end
end
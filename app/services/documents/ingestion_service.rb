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
  
  # Process the course material: extract text, chunk, and generate embeddings
  def process!
    return false unless valid?
    
    load_course_material
    return false unless course_material&.file&.attached?
    
    begin
      # Extract text from PDF
      extracted_text = extract_pdf_text
      return false unless extracted_text
      
      # Split into chunks  
      chunks_data = create_text_chunks(extracted_text)
      return false if chunks_data.empty?
      
      # Generate embeddings and save chunks
      save_chunks_with_embeddings(chunks_data)
      
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
    
    unless @course_material.file.attached?
      add_error("No file attached to course material")
      return false
    end
    
    true
  end
  
  def extract_pdf_text
    # Download the file temporarily for processing
    course_material.file.open do |tempfile|
      processor = Documents::PdfProcessor.new(tempfile.path)
      text = processor.extract_text
      
      unless processor.success?
        processor.errors.each { |error| add_error(error) }
        return nil
      end
      
      text
    end
  rescue StandardError => e
    add_error("Failed to process PDF: #{e.message}")
    nil
  end
  
  def create_text_chunks(text)
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
    chunks_data.each_with_index do |chunk_text, index|
      begin
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
        
        Rails.logger.debug "Processed chunk #{index + 1}/#{chunks_data.size} for course material #{course_material_id}"
        
      rescue StandardError => e
        Rails.logger.error "Failed to process chunk #{index + 1}: #{e.message}"
        add_error("Failed to process chunk #{index + 1}: #{e.message}")
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
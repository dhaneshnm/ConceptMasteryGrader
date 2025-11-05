# Service for extracting text from uploaded PDF files.
# Uses pdf-reader gem to parse PDF content and extract readable text.
class Documents::PdfProcessor
  attr_reader :file_path, :errors
  
  def initialize(file_path)
    @file_path = file_path
    @errors = []
  end
  
  # Extract text from PDF file
  # Returns string with all text content or nil if extraction fails
  def extract_text
    return nil unless valid_pdf?
    
    begin
      reader = PDF::Reader.new(file_path)
      text_content = []
      
      reader.pages.each do |page|
        page_text = page.text
        text_content << page_text if page_text.present?
      end
      
      full_text = text_content.join("\n\n")
      
      if full_text.blank?
        add_error("No readable text found in PDF")
        return nil
      end
      
      clean_text(full_text)
    rescue PDF::Reader::MalformedPDFError => e
      add_error("Malformed PDF file: #{e.message}")
      nil
    rescue PDF::Reader::UnsupportedFeatureError => e
      add_error("Unsupported PDF feature: #{e.message}")
      nil
    rescue StandardError => e
      add_error("Failed to extract text: #{e.message}")
      nil
    end
  end
  
  # Check if processing was successful
  def success?
    errors.empty?
  end
  
  private
  
  def valid_pdf?
    unless File.exist?(file_path)
      add_error("File does not exist: #{file_path}")
      return false
    end
    
    unless File.readable?(file_path)
      add_error("File is not readable: #{file_path}")
      return false
    end
    
    true
  end
  
  def clean_text(text)
    # Remove excessive whitespace and normalize line breaks
    text.gsub(/\s+/, ' ')
        .gsub(/\n\s*\n/, "\n\n")
        .strip
  end
  
  def add_error(message)
    errors << message
  end
end
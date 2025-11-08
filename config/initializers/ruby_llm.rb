# Configure ruby_llm with default model
require 'ruby_llm'

# Create LLM alias as specified in the plan
LLM = RubyLLM

LLM.config.default_model = "gpt-4.1"

# Optional: Configure API keys via environment variables
# LLM.config.openai_api_key = ENV["OPENAI_API_KEY"] 
# LLM.config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
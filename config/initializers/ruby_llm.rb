RubyLLM.configure do |config|
  # Default model — can be overridden per-provider
  config.default_model = ENV.fetch("RUBY_LLM_MODEL", "gpt-4.1-mini")

  # Configure whichever providers you want. Set the corresponding ENV vars.
  config.openai_api_key     = ENV["OPENAI_API_KEY"] if ENV["OPENAI_API_KEY"]
  config.anthropic_api_key  = ENV["ANTHROPIC_API_KEY"] if ENV["ANTHROPIC_API_KEY"]
  config.gemini_api_key     = ENV["GEMINI_API_KEY"] if ENV["GEMINI_API_KEY"]
  config.ollama_api_key     = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"]
end

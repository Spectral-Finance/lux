import Config

# Ollama Local LLM Configuration
#
# This configuration file contains settings for the Ollama local LLM provider.
# Ollama enables self-hosted LLM capabilities with optimized performance.
#
# Prerequisites:
#   1. Install Ollama: https://ollama.ai/download
#   2. Start the Ollama service: `ollama serve`
#   3. Pull a model: `ollama pull llama3.2`
#
# Environment Variables (optional):
#   - OLLAMA_HOST: Override the default endpoint (default: http://localhost:11434)
#   - OLLAMA_MODEL: Override the default model (default: llama3.2)

# Model presets for different use cases
config :lux, :ollama_models,
  # Default model for general use - good balance of speed and capability
  default: System.get_env("OLLAMA_MODEL", "llama3.2"),

  # Largest/most capable model for complex tasks
  smartest: "llama3.2:70b",

  # Smallest/fastest model for quick responses
  fastest: "llama3.2:1b",

  # Specialized model for code generation
  coding: "codellama",

  # Model for embeddings (if supported)
  embeddings: "nomic-embed-text"

# HTTP client configuration for Ollama
config :lux, Lux.LLM.Ollama,
  # Ollama server endpoint
  endpoint: System.get_env("OLLAMA_HOST", "http://localhost:11434"),

  # HTTP request timeout (ms) - local inference can take time
  receive_timeout: 120_000,

  # Connection pool settings
  pool_size: 4,
  max_connections: 10

# Performance tuning (adjust based on your hardware)
# These can be overridden per-request via config options
#
# Example usage:
#   Lux.LLM.Ollama.call("prompt", [], %{
#     num_gpu: 1,        # Number of GPU layers
#     num_ctx: 4096,     # Context window size
#     num_predict: 512   # Max tokens to generate
#   })

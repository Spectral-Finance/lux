import Config

config :lux, :ollama_models,
  default: "qwen2.5:7b",
  available: [
    "qwen2.5:7b",
    "deepseek-coder:33b",
    "gemma-4-31b",
    "qwen3:8b",
    "llama3:8b",
    "llama3:70b",
    "mistral:7b",
    "mixtral:8x7b",
    "codellama:34b",
    "phi3:14b",
    "gemma2:27b",
    "command-r:35b",
    "wizardlm2:7b",
    "dolphin-mixtral:8x7b",
    "nomic-embed-text"
  ]

config :lux, :ollama_endpoint, "http://localhost:11434"

config :lux, Lux.LLM.Ollama,
  receive_timeout: 120_000

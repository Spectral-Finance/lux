import Config

# Erlport python options
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

config :lux, :together_ai_models,
  default: "mistralai/Mistral-7B-Instruct-v0.2"

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

config :venomous, :snake_manager, %{
  snake_ttl_minutes: 10,
  perpetual_workers: 2,
  # Interval for killing python processes past their ttl while inactive
  cleaner_interval: 60_000,
  python_opts: [
    module_paths: ["priv/python"],
    compressed: 0,
    packet_bytes: 4,
    # Use python3 command instead of full path
    python_executable: "python3"
  ]
}

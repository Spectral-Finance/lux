import Config

# Erlport python options
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

config :lux, :together_ai_models,
  default: "mistralai/Mistral-7B-Instruct-v0.2"

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

config :lux, Lux.LLM.Ollama,
  endpoint: {:runtime_config, :ollama, [:endpoint], "http://localhost:11434"},
  model: {:runtime_config, :ollama, [:model], "llama3"},
  max_concurrency: {:runtime_config, :ollama, [:max_concurrency], 2},
  model_ttl: {:runtime_config, :ollama, [:model_ttl], :timer.minutes(30)},
  cleanup_interval: {:runtime_config, :ollama, [:cleanup_interval], :timer.minutes(10)},
  auto_pull: {:runtime_config, :ollama, [:auto_pull], true},
  request_timeout: {:runtime_config, :ollama, [:request_timeout], 30_000},
  pull_timeout: {:runtime_config, :ollama, [:pull_timeout], 120_000}

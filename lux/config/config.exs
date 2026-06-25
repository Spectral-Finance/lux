import Config

# LLM Provider registry
config :lux, :providers,
  openai: [module: Lux.LLM.OpenAI, priority: 1],
  anthropic: [module: Lux.LLM.Anthropic, priority: 2],
  together_ai: [module: Lux.LLM.TogetherAI, priority: 3],
  mira: [module: Lux.LLM.Mira, priority: 4],
  openrouter: [module: Lux.LLM.OpenRouter, priority: 5]

# Erlport python options
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

config :lux, :together_ai_models,
  default: "mistralai/Mistral-7B-Instruct-v0.2"

config :lux, :openrouter_models,
  cheapest: "meta-llama/llama-3.1-8b-instruct",
  default: "anthropic/claude-3.5-sonnet",
  smartest: "anthropic/claude-3-opus"

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

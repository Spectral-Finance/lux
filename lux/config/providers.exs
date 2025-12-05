import Config

# LLM Provider Manager Configuration
#
# This configuration file contains settings for the universal LLM provider manager.
# The ProviderManager enables automatic model selection, fallback handling,
# and cost/performance tracking across all LLM providers.
#
# Environment Variables:
#   - LUX_DEFAULT_PROVIDER: Override the default provider (openai, anthropic, ollama, together, mira)
#   - LUX_COST_TRACKING: Enable/disable cost tracking (true/false)
#   - LUX_CACHE_ENABLED: Enable/disable response caching (true/false)

config :lux, Lux.LLM.ProviderManager,
  # Default provider for LLM calls when none specified
  # Options: :openai, :anthropic, :ollama, :together, :mira
  default_provider:
    System.get_env("LUX_DEFAULT_PROVIDER", "openai")
    |> String.to_atom(),

  # Fallback chain - providers tried in order if the primary fails
  # This ensures high availability by automatically trying alternatives
  fallback_chain: [:openai, :anthropic, :ollama],

  # Cost tracking - record estimated API costs per call
  # Useful for budgeting and monitoring API spend
  cost_tracking: System.get_env("LUX_COST_TRACKING", "true") == "true",

  # Response caching - cache identical requests to reduce API calls
  # Improves performance and reduces costs for repeated queries
  cache_enabled: System.get_env("LUX_CACHE_ENABLED", "false") == "true",

  # Cache TTL in milliseconds (default: 1 hour)
  cache_ttl: :timer.hours(1)

# Provider-specific cost configurations (per 1K tokens in USD)
# These are approximate rates and should be updated as pricing changes
config :lux, :provider_costs,
  openai: %{
    input: 0.0015,  # GPT-4o-mini input
    output: 0.002   # GPT-4o-mini output
  },
  anthropic: %{
    input: 0.003,   # Claude 3 Haiku input
    output: 0.015   # Claude 3 Haiku output
  },
  ollama: %{
    input: 0.0,     # Local - no cost
    output: 0.0
  },
  together: %{
    input: 0.0002,  # Mistral 7B input
    output: 0.0002  # Mistral 7B output
  },
  mira: %{
    input: 0.001,
    output: 0.001
  }

# Task-to-provider mappings
# These define which providers are recommended for different task types
config :lux, :task_providers,
  # Code generation and analysis
  coding: [:anthropic, :openai, :ollama],
  # Creative writing and content generation
  creative: [:anthropic, :openai],
  # Data analysis and structured reasoning
  analysis: [:openai, :anthropic],
  # Local-only tasks (privacy sensitive)
  local: [:ollama],
  # Budget-conscious tasks
  cheap: [:ollama, :together],
  # Low-latency tasks
  fast: [:ollama, :together, :openai]

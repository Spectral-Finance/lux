import Config

# Anthropic API configuration
config :lux, :anthropic_models,
  default: "claude-3-sonnet-20240229",
  available: [
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307"
  ]

# Token cache configuration
config :lux, Lux.LLM.Anthropic.TokenCache,
  enabled: true,
  ttl: 3600,  # Time to live in seconds
  max_size: 10_000  # Maximum number of entries in the cache

# Load balancing configuration
config :lux, Lux.LLM.Anthropic.LoadBalancer,
  enabled: true,
  strategy: :round_robin,  # Options: :round_robin, :weighted, :random
  retry_attempts: 3,
  retry_backoff: 500  # Backoff in milliseconds

# Performance monitoring
config :lux, Lux.LLM.Anthropic.Telemetry,
  enabled: true,
  sample_rate: 0.1  # Sample 10% of requests for detailed telemetry

# HTTP client configuration
config :lux, Lux.LLM.Anthropic,
  receive_timeout: 60_000,
  pool_size: 10,
  max_connections: 100

import Config

# Erlport python options
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

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

# Add Hammer configuration
config :hammer,
  backend: {Hammer.Backend.ETS, 
    [
      expiry_ms: 60_000 * 60 * 4,       # 4 hours
      cleanup_interval_ms: 60_000 * 10,  # 10 minutes
      pool_size: 1,
      pool_max_overflow: 2
    ]
  }

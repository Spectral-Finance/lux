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
import Config

config :lux,
  defi_analytics: [
    api_key: System.get_env("DEFI_LLAMA_API_KEY"),
    base_url: "https://api.llama.fi",
    dune_api_key: System.get_env("DUNE_API_KEY"),
    dune_base_url: "https://dune.com",
    tvl_endpoint: "/tvl",
    metrics_endpoint: "/metrics",
    yield_endpoint: "/yields",
    volume_endpoint: "/volumes",
    query_endpoint: "/queries",
    dashboard_endpoint: "/dashboards"
  ]

config :lux, :analytics do
  config :lux, :analytics do
    api_key: System.get_env("DEFI_LLAMA_API_KEY"),
    base_url: "https://dune.com",
    endpoints: [
      tvl: "/tvl",
      metrics: "/metrics",
      yield: "/yields",
      volume: "/volumes",
      queries: "/queries",
      dashboard: "/dashboards"
    ]
  end
end
}

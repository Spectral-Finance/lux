# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :lux,
  ecto_repos: [Lux.Repo],
  generators: [binary_id: true]

config :lux, Lux.GasOptimizer,
  enabled: true,
  gas_price_prediction_interval: 1, # minute
  transaction_batching_threshold: 10, # number of transactions
  priority_fee_optimization_enabled: true,
  mev_protection_enabled: true,
  gas_token_integration_enabled: true

# Configures the endpoint
config :lux, LuxWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: LuxWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: Lux.PubSub,
  live_view: [signing_salt: "some_salt"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
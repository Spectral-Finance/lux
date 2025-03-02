import Config
import Dotenvy

if config_env() == :test do
  source([
    "../test.envrc",
    "../test.override.envrc"
  ])
else
  source(["../#{config_env()}.envrc", "../#{config_env()}.override.envrc", System.get_env()])
end

config :lux, env: config_env()

# Configure the database
config :lux, Lux.Repo,
  database: env!("LUX_POSTGRES_DB", :string!, "lux_#{config_env()}"),
  username: env!("LUX_POSTGRES_USER", :string!, "postgres"),
  password: env!("LUX_POSTGRES_PASSWORD", :string!, "postgres"),
  hostname: env!("LUX_POSTGRES_HOST", :string!, "localhost"),
  port: env!("LUX_POSTGRES_PORT", :integer!, 5432)

# Use sandbox for testing
if config_env() == :test do
  config :lux, Lux.Repo, pool: Ecto.Adapters.SQL.Sandbox
end

if config_env() in [:dev, :test] do
  config :lux, :api_keys,
    alchemy: env!("ALCHEMY_API_KEY", :string!),
    openai: env!("OPENAI_API_KEY", :string!),
    openweather: env!("OPENWEATHER_API_KEY", :string!),
    transpose: env!("TRANSPOSE_API_KEY", :string!),
    integration_openai: env!("INTEGRATION_OPENAI_API_KEY", :string!, required: false),
    integration_openweather: env!("INTEGRATION_OPENWEATHER_API_KEY", :string!, required: false),
    integration_transpose: env!("INTEGRATION_TRANSPOSE_API_KEY", :string!, required: false)

  config :lux, :accounts,
    wallet_address: env!("WALLET_ADDRESS", :string!),
    hyperliquid_private_key: env!("HYPERLIQUID_PRIVATE_KEY", :string!),
    hyperliquid_address: env!("HYPERLIQUID_ADDRESS", :string!, required: false),
    hyperliquid_api_url: env!("HYPERLIQUID_API_URL", :string!)

  config :ethers,
    default_signer: Ethers.Signer.Local,
    default_signer_opts: [
      private_key: env!("WALLET_PRIVATE_KEY", :string!),
      rpc_url: env!("RPC_URL", :string!)
    ]

  config :ethereumex,
    url: env!("RPC_URL", :string!)

  config :logger,
    level: env!("LOG_LEVEL", :atom!, :debug)
end

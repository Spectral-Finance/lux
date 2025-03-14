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

if config_env() in [:dev, :test] do
  config :lux, :api_keys,
    alchemy: env!("ALCHEMY_API_KEY", :string!),
    openai: env!("OPENAI_API_KEY", :string!),
    anthropic: env!("ANTHROPIC_API_KEY", :string!),
    openweather: env!("OPENWEATHER_API_KEY", :string!),
    transpose: env!("TRANSPOSE_API_KEY", :string!),
    etherscan: env!("ETHERSCAN_API_KEY", :string!),
    etherscan_pro: env!("ETHERSCAN_API_KEY_PRO", :string!, required: false) == "true",
    integration_openai: env!("INTEGRATION_OPENAI_API_KEY", :string!, required: false),
    integration_anthropic: env!("INTEGRATION_ANTHROPIC_API_KEY", :string!, required: false),
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

  config :nostrum,
    token: env!("DISCORD_TOKEN", :string!),
    gateway_intents: :all

  config :logger,
    level: env!("LOG_LEVEL", :atom!, :debug)
end


if config_env() == :test do
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
end

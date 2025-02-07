import Config
import Dotenvy

if config_env() == :test do
  source([
    "test.envrc",
    "test.override.envrc"
  ])
else
  source(["#{config_env()}.envrc", "#{config_env()}.override.envrc", System.get_env()])
end

config :lux, env: config_env()

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
    hyperliquid_private_key: env!("HYPERLIQUID_PRIVATE_KEY", :string!),
    hyperliquid_address: env!("HYPERLIQUID_ADDRESS", :string!, required: false),
    hyperliquid_api_url: env!("HYPERLIQUID_API_URL", :string!)
end

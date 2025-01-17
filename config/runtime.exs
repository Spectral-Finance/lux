import Config
import Dotenvy

if config_env() == :test do
  source(["test.envrc", "test.override.envrc"])
else
  source(["#{config_env()}.envrc", "#{config_env()}.override.envrc", System.get_env()])
end

config :lux, :api_keys,
  alchemy: env!("ALCHEMY_API_KEY", :string!, "fake_alchemy_api_key"),
  openai: env!("OPENAI_API_KEY", :string!, "fake_openai_api_key")

config :lux, :config_env, config_env()

import Config
import Dotenvy

if config_env() == :test do
  source(["test.envrc", "test.override.envrc"])
else
  source(["#{config_env()}.envrc", "#{config_env()}.override.envrc", System.get_env()])
<<<<<<< HEAD
=======
end

if config_env() in [:dev, :test] do
  config :lux, :api_keys,
    alchemy: env!("ALCHEMY_API_KEY"),
    openai: env!("OPENAI_API_KEY")
>>>>>>> 43c7337 (feat: update env variable files)
end

config :lux, :api_keys,
  alchemy: env!("ALCHEMY_API_KEY", :string!, "fake_alchemy_api_key"),
  openai: env!("OPENAI_API_KEY", :string!, "fake_openai_api_key")

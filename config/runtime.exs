import Config

# Load environment variables if in dev/test
if config_env() in [:dev, :test] do
  env_config =
    [".env"]
    |> Dotenvy.source!(system_vars: true)
    |> Map.take(["ALCHEMY_API_KEY", "OPENAI_API_KEY"])

  config :lux, :api_keys,
    alchemy: env_config["ALCHEMY_API_KEY"],
    openai: env_config["OPENAI_API_KEY"]
end

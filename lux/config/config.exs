import Config

# OpenRouter config import
import OpenRouter.Config

# Erlport python options
config :lux, :open_ai_models do
  case Mix.env() do
    :dev -> [cheapest: "gpt-4o-mini-dev", default: "gpt-4o-mini-dev", smartest: "gpt-4o-dev"]
    :test -> [cheapest: "gpt-4o-mini-test", default: "gpt-4o-mini-test", smartest: "gpt-4o-test"]
    _ -> [cheapest: "gpt-4o-mini", default: "gpt-4o-mini", smartest: "gpt-4o"]
  end
end

config :lux, :together_ai_models do
  case Mix.env() do
    :dev -> [default: "mistralai/Mistral-7B-Instruct-v0.2-dev"]
    :test -> [default: "mistralai/Mistral-7B-Instruct-v0.2-test"]
    _ -> [default: "mistralai/Mistral-7B-Instruct-v0.2"]
  end
end

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

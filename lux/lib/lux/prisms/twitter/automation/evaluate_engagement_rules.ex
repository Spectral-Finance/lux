defmodule Lux.Prisms.Twitter.Automation.EvaluateEngagementRules do
  @moduledoc """
  A prism for evaluating tweets against declarative engagement rules while respecting daily action caps.
  """

  use Lux.Prism,
    name: "Evaluate Twitter Engagement Rules",
    description: "Evaluates tweets against conditional rules and checks safety daily action limits",
    input_schema: %{
      type: :object,
      properties: %{
        tweet: %{type: :object, description: "Tweet payload to evaluate"},
        rules: %{type: :array, description: "List of rule definitions"},
        daily_usage: %{type: :object, description: "Map of action to current count today"},
        caps: %{type: :object, description: "Custom daily action caps"}
      },
      required: ["tweet", "rules"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        matched_rules: %{type: :array},
        approved_actions: %{type: :array},
        throttled_actions: %{type: :array}
      },
      required: ["matched_rules", "approved_actions"]
    }

  alias Lux.Integrations.Twitter.Automation.EngagementRulesEngine

  def handler(params, _agent) when is_map(params) do
    tweet = Map.get(params, :tweet) || Map.get(params, "tweet")
    rules = Map.get(params, :rules) || Map.get(params, "rules", [])
    daily_usage = Map.get(params, :daily_usage) || Map.get(params, "daily_usage", %{})
    caps = Map.get(params, :caps) || Map.get(params, "caps", %{})

    case EngagementRulesEngine.evaluate(tweet, rules, daily_usage, caps) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters: expected tweet and rules"}
end

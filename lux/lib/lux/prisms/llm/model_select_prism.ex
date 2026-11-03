defmodule Lux.Prisms.LLM.ModelSelectPrism do
  @moduledoc """
  A prism for dynamically choosing the optimal LLM provider and model
  based on intent, cost tiers, latency constraints, and tool requirements.
  """

  use Lux.Prism,
    name: "LLM Model Select Prism",
    description: "Evaluates requirements and selects optimal LLM provider and model",
    input_schema: %{
      type: :object,
      properties: %{
        strategy: %{
          type: :string,
          enum: ["cost_optimized", "performance", "reasoning_quality", "offline_privacy", "research", "balanced"],
          default: "balanced"
        },
        require_tools: %{type: :boolean, default: false},
        preferred_provider: %{type: :string}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        provider_id: %{type: :string},
        provider_name: %{type: :string},
        model: %{type: :string},
        cost_tier: %{type: :string}
      },
      required: ["provider_id", "model"]
    }

  alias Lux.LLM.Router

  @impl true
  def handler(inputs, _context) do
    strat_str = Map.get(inputs, "strategy") || Map.get(inputs, :strategy, "balanced")
    req_tools = Map.get(inputs, "require_tools") || Map.get(inputs, :require_tools, false)
    preferred = Map.get(inputs, "preferred_provider") || Map.get(inputs, :preferred_provider)

    strategy_atom = String.to_atom(to_string(strat_str))
    preferred_atom = if preferred, do: String.to_atom(to_string(preferred)), else: nil

    opts = %{
      strategy: strategy_atom,
      require_tools: req_tools,
      preferred_provider: preferred_atom
    }

    case Router.select_provider(opts) do
      {:ok, selection} ->
        {:ok,
         %{
           provider_id: to_string(selection.provider_id),
           provider_name: selection.provider_name,
           model: selection.model,
           cost_tier: to_string(selection.cost_tier)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

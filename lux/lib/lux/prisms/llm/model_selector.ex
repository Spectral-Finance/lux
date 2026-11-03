defmodule Lux.Prisms.Llm.ModelSelectorPrism do
  @moduledoc """
  Selects optimal LLM model according to cost, speed, or reasoning requirements.
  """

  use Lux.Prism,
    name: "LLM Model Selector",
    description: "Chooses the best LLM model according to strategy and required capabilities",
    input_schema: %{
      type: :object,
      properties: %{
        strategy: %{type: :string, default: "balanced"},
        required_capabilities: %{type: :array, default: []},
        max_input_cost_per_m: %{type: :number, default: 100.0}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string},
        provider: %{type: :string},
        tier: %{type: :string},
        input_cost_per_m: %{type: :number},
        output_cost_per_m: %{type: :number}
      },
      required: ["model", "provider", "tier"]
    }

  alias Lux.LLM.ModelSelector

  def handler(input, _ctx) do
    strat_str = Map.get(input, :strategy) || Map.get(input, "strategy", "balanced")
    strategy = strat_str |> String.downcase() |> String.to_atom()

    caps_raw = Map.get(input, :required_capabilities) || Map.get(input, "required_capabilities", [])
    caps = Enum.map(caps_raw, fn c -> if is_binary(c), do: String.to_atom(c), else: c end)

    criteria = %{
      strategy: strategy,
      required_capabilities: caps,
      max_input_cost_per_m: Map.get(input, :max_input_cost_per_m) || Map.get(input, "max_input_cost_per_m", 100.0)
    }

    case ModelSelector.select_model(criteria) do
      {:ok, model} ->
        {:ok,
         %{
           model: model.model,
           provider: to_string(model.provider),
           tier: to_string(model.tier),
           input_cost_per_m: model.input_cost_per_m,
           output_cost_per_m: model.output_cost_per_m
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

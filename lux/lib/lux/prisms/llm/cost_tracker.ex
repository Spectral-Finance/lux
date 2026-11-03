defmodule Lux.Prisms.Llm.CostTrackerPrism do
  @moduledoc """
  Calculates token inference costs in USD for a specified model.
  """

  use Lux.Prism,
    name: "LLM Cost Tracker",
    description: "Calculates prompt, completion, and total cost in USD for LLM usage",
    input_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string, description: "LLM model identifier"},
        prompt_tokens: %{type: :integer, default: 0},
        completion_tokens: %{type: :integer, default: 0}
      },
      required: ["model"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string},
        total_tokens: %{type: :integer},
        prompt_cost_usd: %{type: :number},
        completion_cost_usd: %{type: :number},
        total_cost_usd: %{type: :number}
      },
      required: ["model", "total_tokens", "total_cost_usd"]
    }

  alias Lux.LLM.CostTracker

  def handler(input, _ctx) do
    model = Map.get(input, :model) || Map.get(input, "model", "gpt-4o-mini")
    p_tokens = Map.get(input, :prompt_tokens) || Map.get(input, "prompt_tokens", 0)
    c_tokens = Map.get(input, :completion_tokens) || Map.get(input, "completion_tokens", 0)

    result = CostTracker.calculate_cost(model, p_tokens, c_tokens)
    {:ok, result}
  end
end

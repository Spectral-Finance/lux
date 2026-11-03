defmodule Lux.Prisms.Llm.OpenRouter.CostPrism do
  @moduledoc """
  A prism for calculating token-level USD costs, tracking cumulative spend,
  and enforcing budget thresholds for OpenRouter invocations.
  """

  use Lux.Prism,
    name: "OpenRouter Cost Tracker",
    description: "Calculates inference costs and checks against budget limits",
    input_schema: %{
      type: :object,
      properties: %{
        model: %{
          type: :string,
          description: "Model ID utilized for the call",
          default: "anthropic/claude-3.5-sonnet"
        },
        prompt_tokens: %{
          type: :integer,
          description: "Number of prompt/input tokens used",
          default: 0
        },
        completion_tokens: %{
          type: :integer,
          description: "Number of completion/output tokens generated",
          default: 0
        },
        budget_limit: %{
          type: :number,
          description: "Optional maximum USD budget threshold for the request or session"
        }
      },
      required: ["prompt_tokens", "completion_tokens"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string},
        prompt_cost: %{type: :number},
        completion_cost: %{type: :number},
        total_cost: %{type: :number},
        budget_exceeded: %{type: :boolean},
        remaining_budget: %{type: [:number, :null]}
      },
      required: ["total_cost", "budget_exceeded"]
    }

  alias Lux.LLM.OpenRouter.ModelRouter

  @impl true
  def handler(inputs, _context) do
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "anthropic/claude-3.5-sonnet")
    prompt_tokens = Map.get(inputs, "prompt_tokens") || Map.get(inputs, :prompt_tokens, 0)
    completion_tokens = Map.get(inputs, "completion_tokens") || Map.get(inputs, :completion_tokens, 0)
    budget_limit = Map.get(inputs, "budget_limit") || Map.get(inputs, :budget_limit)

    cost_data = ModelRouter.estimate_cost(model, prompt_tokens, completion_tokens)
    total_cost = cost_data.total_cost

    {budget_exceeded, remaining_budget} =
      case budget_limit do
        limit when is_number(limit) and limit > 0 ->
          rem = Float.round(limit - total_cost, 6)
          {total_cost > limit, max(0.0, rem)}

        _ ->
          {false, nil}
      end

    {:ok,
     %{
       model: model,
       prompt_cost: cost_data.prompt_cost,
       completion_cost: cost_data.completion_cost,
       total_cost: total_cost,
       budget_exceeded: budget_exceeded,
       remaining_budget: remaining_budget
     }}
  end
end

defmodule Lux.Prisms.Llm.Perplexity.CostPrism do
  @moduledoc """
  A prism for tracking Perplexity token usage and web search query fees.
  """

  use Lux.Prism,
    name: "Perplexity Cost Tracker",
    description: "Calculates total USD expense for Perplexity tokens and search queries",
    input_schema: %{
      type: :object,
      properties: %{
        model: %{
          type: :string,
          description: "Model ID",
          default: "sonar-pro"
        },
        prompt_tokens: %{
          type: :integer,
          default: 0
        },
        completion_tokens: %{
          type: :integer,
          default: 0
        },
        search_queries: %{
          type: :integer,
          default: 1
        },
        budget_limit: %{
          type: :number
        }
      },
      required: ["prompt_tokens", "completion_tokens"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        model: %{type: :string},
        total_cost: %{type: :number},
        prompt_cost: %{type: :number},
        completion_cost: %{type: :number},
        search_cost: %{type: :number},
        budget_exceeded: %{type: :boolean},
        remaining_budget: %{type: [:number, :null]}
      },
      required: ["total_cost", "budget_exceeded"]
    }

  alias Lux.LLM.Perplexity.ModelRouter

  @impl true
  def handler(inputs, _context) do
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "sonar-pro")
    prompt_tokens = Map.get(inputs, "prompt_tokens") || Map.get(inputs, :prompt_tokens, 0)
    completion_tokens = Map.get(inputs, "completion_tokens") || Map.get(inputs, :completion_tokens, 0)
    search_queries = Map.get(inputs, "search_queries") || Map.get(inputs, :search_queries, 1)
    budget_limit = Map.get(inputs, "budget_limit") || Map.get(inputs, :budget_limit)

    cost_data = ModelRouter.estimate_cost(model, prompt_tokens, completion_tokens, search_queries)
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
       total_cost: total_cost,
       prompt_cost: cost_data.prompt_cost,
       completion_cost: cost_data.completion_cost,
       search_cost: cost_data.search_cost,
       budget_exceeded: budget_exceeded,
       remaining_budget: remaining_budget
     }}
  end
end

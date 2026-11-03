defmodule Lux.Prisms.LLM.CostAnalyticsPrism do
  @moduledoc """
  A prism that records usage tokens, calculates dollar costs, and returns analytics summaries.
  """

  use Lux.Prism,
    name: "LLM Cost Analytics Prism",
    description: "Tracks LLM expenditure, estimates costs, and audits budget limits",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["record", "summary", "check_budget"],
          default: "summary"
        },
        provider: %{type: :string},
        model: %{type: :string},
        prompt_tokens: %{type: :integer, default: 0},
        completion_tokens: %{type: :integer, default: 0},
        budget_limit_usd: %{type: :number}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_cost_usd: %{type: :number},
        total_tokens: %{type: :integer},
        status: %{type: :string}
      },
      required: ["total_cost_usd", "status"]
    }

  alias Lux.LLM.CostTracker

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "summary")

    case action do
      "record" ->
        provider = Map.get(inputs, "provider") || Map.get(inputs, :provider, "default")
        model = Map.get(inputs, "model") || Map.get(inputs, :model, "gpt-4o")
        p_tokens = Map.get(inputs, "prompt_tokens") || Map.get(inputs, :prompt_tokens, 0)
        c_tokens = Map.get(inputs, "completion_tokens") || Map.get(inputs, :completion_tokens, 0)

        event = CostTracker.record_usage(provider, model, p_tokens, c_tokens)
        summary = CostTracker.get_summary()

        {:ok,
         %{
           total_cost_usd: summary.total_cost_usd,
           total_tokens: summary.total_tokens,
           status: "recorded: #{event.cost_usd} USD"
         }}

      "check_budget" ->
        budget = Map.get(inputs, "budget_limit_usd") || Map.get(inputs, :budget_limit_usd, 10.0)
        summary = CostTracker.get_summary()

        case CostTracker.check_budget_limit(budget) do
          {:ok, :within_budget, _spend} ->
            {:ok,
             %{
               total_cost_usd: summary.total_cost_usd,
               total_tokens: summary.total_tokens,
               status: "within_budget"
             }}

          {:exceeded, spend, limit} ->
            {:ok,
             %{
               total_cost_usd: spend,
               total_tokens: summary.total_tokens,
               status: "budget_exceeded: limit #{limit}"
             }}
        end

      _summary ->
        summary = CostTracker.get_summary()

        {:ok,
         %{
           total_cost_usd: summary.total_cost_usd,
           total_tokens: summary.total_tokens,
           status: "ok"
         }}
    end
  end
end

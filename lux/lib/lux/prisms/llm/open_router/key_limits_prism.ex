defmodule Lux.Prisms.Llm.OpenRouter.KeyLimitsPrism do
  @moduledoc """
  A prism for checking OpenRouter account credits, limits, and rate limits
  prior to executing workflows.
  """

  use Lux.Prism,
    name: "OpenRouter Key Limits",
    description: "Inspects API key quota, credit balance, and rate limit thresholds",
    input_schema: %{
      type: :object,
      properties: %{
        api_key: %{
          type: :string,
          description: "Optional OpenRouter API key"
        },
        estimated_cost: %{
          type: :number,
          description: "Optional estimated cost in USD to verify against remaining balance",
          default: 0.0
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        label: %{type: [:string, :null]},
        usage: %{type: :number},
        limit: %{type: [:number, :null]},
        credits_remaining: %{type: [:number, :string]},
        usage_percentage: %{type: [:number, :null]},
        is_free_tier: %{type: :boolean},
        rate_limit_requests: %{type: [:integer, :null]},
        rate_limit_interval: %{type: [:string, :null]},
        has_sufficient_credits: %{type: :boolean}
      },
      required: ["usage", "is_free_tier", "has_sufficient_credits"]
    }

  alias Lux.LLM.OpenRouter.KeyLimits

  @impl true
  def handler(inputs, _context) do
    api_key = Map.get(inputs, "api_key") || Map.get(inputs, :api_key)
    estimated_cost = Map.get(inputs, "estimated_cost") || Map.get(inputs, :estimated_cost, 0.0)

    case KeyLimits.get_key_info(api_key) do
      {:ok, %KeyLimits.Info{} = info} ->
        sufficient = KeyLimits.has_sufficient_credits?(info, estimated_cost)

        credits_str_or_num =
          case info.credits_remaining do
            :unlimited -> "unlimited"
            val when is_number(val) -> val
          end

        {:ok,
         %{
           label: info.label,
           usage: info.usage,
           limit: info.limit,
           credits_remaining: credits_str_or_num,
           usage_percentage: info.usage_percentage,
           is_free_tier: info.is_free_tier,
           rate_limit_requests: info.rate_limit_requests,
           rate_limit_interval: info.rate_limit_interval,
           has_sufficient_credits: sufficient
         }}

      {:error, reason} ->
        {:error, "OpenRouter KeyLimitsPrism error: #{inspect(reason)}"}
    end
  end
end

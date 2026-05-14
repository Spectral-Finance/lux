defmodule Lux.Prisms.LLM.ProviderRoutingPrism do
  @moduledoc """
  Prism wrapper for stateless LLM provider routing plans.
  """

  use Lux.Prism,
    name: "LLM Provider Routing",
    description:
      "Builds provider selection, fallback, cost, performance, and cache plans for LLM calls",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string, description: "Prompt used for cache planning"},
        capabilities: %{
          type: :array,
          description: "Required capabilities such as chat, tools, json"
        },
        strategy: %{
          type: :string,
          description: "Routing strategy: balanced, cost, latency, or quality"
        },
        estimated_input_tokens: %{type: :integer},
        estimated_output_tokens: %{type: :integer},
        max_cost_usd: %{type: :number},
        max_latency_ms: %{type: :integer},
        preferred_provider: %{type: :string},
        denied_providers: %{type: :array}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        selected: %{type: :object},
        candidates: %{type: :array},
        fallback_chain: %{type: :array},
        estimated_cost: %{type: :object},
        cache: %{type: :object},
        optimization: %{type: :object},
        coverage: %{type: :array}
      },
      required: ["candidates", "fallback_chain", "estimated_cost", "cache", "optimization"]
    }

  alias Lux.LLM.ProviderRouter

  @impl true
  def handler(input, _context) when is_map(input) do
    {:ok, ProviderRouter.route(input)}
  end
end

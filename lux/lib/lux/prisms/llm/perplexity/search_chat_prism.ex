defmodule Lux.Prisms.Llm.Perplexity.SearchChatPrism do
  @moduledoc """
  A prism for running web-grounded research queries with Perplexity AI.
  Returns generated answers along with web source citations.
  """

  use Lux.Prism,
    name: "Perplexity Search Chat",
    description: "Executes online web-grounded search chat completion and extracts citations",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Research query or question"
        },
        model: %{
          type: :string,
          description: "Model to use ('sonar', 'sonar-pro', 'sonar-reasoning')",
          default: "sonar-pro"
        },
        search_domain_filter: %{
          type: :array,
          items: %{type: :string},
          description: "List of domain filters (prefix with '-' to exclude)"
        },
        search_recency_filter: %{
          type: :string,
          description: "Filter search by recency ('day', 'week', 'month', 'year')"
        },
        temperature: %{
          type: :number,
          default: 0.2
        },
        api_key: %{
          type: :string
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :object]},
        model: %{type: :string},
        citations: %{type: :array, items: %{type: :string}},
        cost_estimate: %{type: :object}
      },
      required: ["content", "model"]
    }

  alias Lux.LLM.Perplexity

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "sonar-pro")
    domains = Map.get(inputs, "search_domain_filter") || Map.get(inputs, :search_domain_filter, [])
    recency = Map.get(inputs, "search_recency_filter") || Map.get(inputs, :search_recency_filter)
    temp = Map.get(inputs, "temperature") || Map.get(inputs, :temperature, 0.2)
    api_key = Map.get(inputs, "api_key") || Map.get(inputs, :api_key)

    config =
      %{
        model: model,
        temperature: temp
      }
      |> maybe_put(:search_domain_filter, (domains != [] && domains) || nil)
      |> maybe_put(:search_recency_filter, recency)
      |> maybe_put(:api_key, api_key)

    case Perplexity.call(prompt, [], config) do
      {:ok, %Lux.Signal{payload: payload, metadata: metadata}} ->
        {:ok,
         %{
           content: payload.content,
           model: payload.model,
           citations: metadata[:citations] || [],
           cost_estimate: metadata[:cost_estimate] || %{}
         }}

      {:error, reason} ->
        {:error, "Perplexity SearchChatPrism error: #{inspect(reason)}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end

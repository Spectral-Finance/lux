defmodule Lux.Prisms.Llm.Perplexity.ReasoningPrism do
  @moduledoc """
  A prism for running deep chain-of-thought reasoning with Perplexity's `sonar-reasoning`
  and `sonar-reasoning-pro` models.
  """

  use Lux.Prism,
    name: "Perplexity Deep Reasoning",
    description: "Executes multi-step online reasoning for complex analytical inquiries",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Complex question requiring reasoning"
        },
        model: %{
          type: :string,
          description: "Reasoning model",
          enum: ["sonar-reasoning-pro", "sonar-reasoning"],
          default: "sonar-reasoning-pro"
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
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "sonar-reasoning-pro")
    api_key = Map.get(inputs, "api_key") || Map.get(inputs, :api_key)

    config =
      %{
        model: model,
        temperature: 0.1
      }
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
        {:error, "Perplexity ReasoningPrism error: #{inspect(reason)}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end

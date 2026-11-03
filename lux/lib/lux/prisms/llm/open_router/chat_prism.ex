defmodule Lux.Prisms.Llm.OpenRouter.ChatPrism do
  @moduledoc """
  A prism for running inference and chat completions through OpenRouter.

  Supports model selection, system prompt configuration, multi-turn messages,
  fallback models, and returns structured results with token usage and cost metrics.
  """

  use Lux.Prism,
    name: "OpenRouter Chat Completion",
    description: "Generates completions using OpenRouter with flexible model choice and token tracking",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Prompt or user query for the model"
        },
        model: %{
          type: :string,
          description: "Model ID (e.g. 'anthropic/claude-3.5-sonnet', 'openai/gpt-4o-mini')",
          default: "anthropic/claude-3.5-sonnet"
        },
        models: %{
          type: :array,
          items: %{type: :string},
          description: "Optional list of fallback model IDs in order of preference"
        },
        temperature: %{
          type: :number,
          description: "Sampling temperature (0.0 to 2.0)",
          default: 0.7
        },
        max_tokens: %{
          type: :integer,
          description: "Maximum tokens to generate"
        },
        api_key: %{
          type: :string,
          description: "Optional OpenRouter API key override"
        }
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content: %{type: [:string, :object]},
        model: %{type: :string},
        finish_reason: %{type: :string},
        usage: %{type: :object},
        cost_estimate: %{type: :object}
      },
      required: ["content", "model"]
    }

  alias Lux.LLM.OpenRouter

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "anthropic/claude-3.5-sonnet")
    models = Map.get(inputs, "models") || Map.get(inputs, :models, [])
    temperature = Map.get(inputs, "temperature") || Map.get(inputs, :temperature, 0.7)
    max_tokens = Map.get(inputs, "max_tokens") || Map.get(inputs, :max_tokens)
    api_key = Map.get(inputs, "api_key") || Map.get(inputs, :api_key)

    config =
      %{
        model: model,
        temperature: temperature
      }
      |> maybe_put(:models, models)
      |> maybe_put(:max_tokens, max_tokens)
      |> maybe_put(:api_key, api_key)

    case OpenRouter.call(prompt, [], config) do
      {:ok, %Lux.Signal{payload: payload, metadata: metadata}} ->
        {:ok,
         %{
           content: payload.content,
           model: payload.model,
           finish_reason: payload.finish_reason,
           usage: metadata[:usage] || %{},
           cost_estimate: metadata[:cost_estimate] || %{}
         }}

      {:error, reason} ->
        {:error, "OpenRouter ChatPrism error: #{inspect(reason)}"}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, []), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end

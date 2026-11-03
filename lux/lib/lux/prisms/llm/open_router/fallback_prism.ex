defmodule Lux.Prisms.Llm.OpenRouter.FallbackPrism do
  @moduledoc """
  A prism that manages resilient multi-model fallback cascades for OpenRouter.

  If a primary model is throttled or fails, this prism automatically steps through
  the ordered fallback list until a successful generation is returned or the chain is exhausted.
  """

  use Lux.Prism,
    name: "OpenRouter Resilient Fallback",
    description: "Executes LLM completions with client-side fallback across multiple models",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{
          type: :string,
          description: "Prompt or instruction to complete"
        },
        models: %{
          type: :array,
          items: %{type: :string},
          description: "Ordered list of model IDs to attempt in sequence",
          default: ["anthropic/claude-3.5-sonnet", "openai/gpt-4o-mini", "meta-llama/llama-3.1-8b-instruct:free"]
        },
        temperature: %{
          type: :number,
          default: 0.7
        },
        max_tokens: %{
          type: :integer
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
        model_used: %{type: :string},
        attempts: %{type: :integer},
        errors: %{type: :array, items: %{type: :string}},
        usage: %{type: :object},
        cost_estimate: %{type: :object}
      },
      required: ["content", "model_used", "attempts"]
    }

  alias Lux.LLM.OpenRouter
  require Logger

  @impl true
  def handler(inputs, _context) do
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt)

    models =
      Map.get(inputs, "models") ||
        Map.get(inputs, :models, [
          "anthropic/claude-3.5-sonnet",
          "openai/gpt-4o-mini",
          "meta-llama/llama-3.1-8b-instruct:free"
        ])

    temperature = Map.get(inputs, "temperature") || Map.get(inputs, :temperature, 0.7)
    max_tokens = Map.get(inputs, "max_tokens") || Map.get(inputs, :max_tokens)
    api_key = Map.get(inputs, "api_key") || Map.get(inputs, :api_key)

    attempt_cascade(models, prompt, temperature, max_tokens, api_key, 1, [])
  end

  defp attempt_cascade([], _prompt, _temp, _max_tokens, _api_key, attempts, errors) do
    {:error, "All #{attempts - 1} models in fallback chain failed: #{inspect(errors)}"}
  end

  defp attempt_cascade([current_model | remaining_models], prompt, temp, max_tokens, api_key, attempt, errors) do
    config =
      %{
        model: current_model,
        temperature: temp
      }
      |> maybe_put(:max_tokens, max_tokens)
      |> maybe_put(:api_key, api_key)

    case OpenRouter.call(prompt, [], config) do
      {:ok, %Lux.Signal{payload: payload, metadata: metadata}} ->
        {:ok,
         %{
           content: payload.content,
           model_used: payload.model || current_model,
           attempts: attempt,
           errors: errors,
           usage: metadata[:usage] || %{},
           cost_estimate: metadata[:cost_estimate] || %{}
         }}

      {:error, reason} ->
        error_msg = "#{current_model}: #{inspect(reason)}"
        Logger.warning("OpenRouter fallback attempt #{attempt} failed for #{current_model}: #{inspect(reason)}")

        attempt_cascade(
          remaining_models,
          prompt,
          temp,
          max_tokens,
          api_key,
          attempt + 1,
          errors ++ [error_msg]
        )
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)
end

defmodule Lux.Prisms.OpenRouter.OpenRouterChatPrism do
  @moduledoc """
  A prism that sends chat completion requests via OpenRouter using Lux.LLM.OpenRouter.

  ## Example

      iex> Lux.Prisms.OpenRouter.OpenRouterChatPrism.run(%{
      ...>   model: "openai/gpt-4o-mini",
      ...>   prompt: "Hello!",
      ...>   temperature: 0.7
      ...> })
      {:ok, %{status: "success", content: "Hello! How can I help?", model: "openai/gpt-4o-mini"}}
  """

  use Lux.Prism,
    name: "OpenRouter Chat Completion",
    description: "Sends chat completion requests via OpenRouter supporting 200+ LLM models",
    input_schema: %{
      type: :object,
      properties: %{
        prompt: %{type: :string, description: "User prompt to send"},
        model: %{type: :string, description: "Model ID e.g. openai/gpt-4o-mini", default: "openai/gpt-4o-mini"},
        temperature: %{type: :number, description: "Sampling temperature 0.0-2.0", default: 0.7},
        max_tokens: %{type: :integer, description: "Maximum tokens to generate", default: 1000}
      },
      required: ["prompt"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        content: %{type: :string},
        model: %{type: :string},
        usage: %{type: :object}
      },
      required: ["status", "content"]
    }

  alias Lux.LLM.OpenRouter
  require Logger

  def handler(input, _ctx) do
    prompt      = input[:prompt] || input["prompt"]
    model       = input[:model] || input["model"] || "openai/gpt-4o-mini"
    temperature = input[:temperature] || input["temperature"] || 0.7
    max_tokens  = input[:max_tokens] || input["max_tokens"] || 1000

    config = %{
      model: model,
      temperature: temperature,
      max_tokens: max_tokens,
      json_response: false
    }

    case OpenRouter.call(prompt, [], config) do
      {:ok, signal} ->
        {:ok, %{
          status: "success",
          content: signal.payload.content || "",
          model: signal.payload.model || model,
          usage: signal.metadata.usage || %{}
        }}
      {:error, reason} ->
        Logger.error("OpenRouter chat failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

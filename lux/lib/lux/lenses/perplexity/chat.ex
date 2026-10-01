defmodule Lux.Lenses.Perplexity.Chat do
  @moduledoc """
  Chat Completions lens for Perplexity AI.

  ## Example

  ```elixir
  alias Lux.Lenses.Perplexity.Chat

  Chat.focus(%{
    model: "sonar-pro",
    messages: [
      %{role: "system", content: "You are a helpful assistant."},
      %{role: "user", content: "What is the capital of France?"}
    ]
  })
  ```
  """

  use Lux.Lens,
    name: "Perplexity Chat Completions",
    description: "Send messages to Perplexity AI and get completions",
    url: "https://api.perplexity.ai/chat/completions",
    method: :post,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Lenses.Perplexity.Base.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        model: %{
          type: :string,
          description: "Model to use for completion",
          enum: ["sonar", "sonar-pro", "sonar-reasoning", "sonar-deep-research"],
          default: "sonar"
        },
        messages: %{
          type: :array,
          description: "Messages in the chat conversation",
          items: %{
            type: :object,
            properties: %{
              role: %{type: :string, enum: ["system", "user", "assistant"]},
              content: %{type: :string}
            },
            required: ["role", "content"]
          }
        },
        temperature: %{
          type: :number,
          description: "Sampling temperature",
          default: 0.2
        },
        stream: %{
          type: :boolean,
          description: "Whether to stream the response",
          default: false
        }
      },
      required: ["model", "messages"]
    }

  @doc """
  Transforms the API response.
  """
  @impl true
  def after_focus(%{"id" => _id, "choices" => choices} = response) do
    # Extract usage for cost tracking
    usage = response["usage"] || %{}
    
    transformed = %{
      choices: Enum.map(choices, fn choice ->
        %{
          message: choice["message"],
          finish_reason: choice["finish_reason"]
        }
      end),
      usage: %{
        prompt_tokens: usage["prompt_tokens"],
        completion_tokens: usage["completion_tokens"],
        total_tokens: usage["total_tokens"]
      }
    }

    {:ok, transformed}
  end

  @impl true
  def after_focus(response) do
    Lux.Lenses.Perplexity.Base.handle_response(response)
  end
end

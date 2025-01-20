defmodule Lux.LLM.ResponseSchema do
  @moduledoc """
  Schema for LLM responses. Defines the structure of responses from language models.
  """

  use Lux.SignalSchema,
    name: "llm_response",
    version: "1.0.0",
    description: "Schema for responses from language models",
    schema: %{
      type: :object,
      properties: %{
        content: %{
          type: :string,
          description: "The text content of the response"
        },
        tool_calls: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              name: %{type: :string},
              arguments: %{type: :object}
            },
            required: ["name", "arguments"]
          },
          description: "List of tool calls requested by the model"
        },
        usage: %{
          type: :object,
          properties: %{
            prompt_tokens: %{type: :integer},
            completion_tokens: %{type: :integer},
            total_tokens: %{type: :integer}
          },
          description: "Token usage information"
        },
        model: %{
          type: :string,
          description: "The model that generated this response"
        }
      },
      required: ["content"]
    },
    tags: ["llm", "response"],
    compatibility: :full,
    format: :json
end

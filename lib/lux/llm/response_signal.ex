defmodule Lux.LLM.ResponseSignal do
  @moduledoc """
  A SignalSchema to represent an LLM response.
  It contains the content, model,tool calls, and finish reason.
  Any other data should be stored in the Signal's metadata field.
  """
  use Lux.SignalSchema,
    name: "llm_response",
    version: "1.0.0",
    description: "Represents a response from an LLM",
    schema: %{
      type: :object,
      properties: %{
        content: %{anyOf: [%{type: :object}, %{type: :null}]},
        # content: %{type: :object},
        model: %{type: :string},
        finish_reason: %{type: :string},
        tool_calls: %{
          anyOf: [
            %{
              type: :array,
              items: %{type: :object},
              default: []
            },
            %{type: :null}
          ]
        },
        tool_calls_results: %{
          anyOf: [
            %{type: :array, items: %{type: :object}, default: []},
            %{type: :null}
          ]
        }
      },
      required: ["content", "model", "finish_reason", "tool_calls"]
    },
    tags: ["llm", "response"],
    compatibility: :full,
    format: :json
end

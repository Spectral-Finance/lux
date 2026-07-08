defmodule Lux.Signal.Chat do
  @moduledoc """
  Defines the schema for chat messages between agents.
  """

  use Lux.SignalSchema,
    name: "Chat Signal",
    version: "1.0.0",
    description: "Schema for chat messages between agents",
    schema: %{
      "type" => "object",
      "properties" => %{
        "message" => %{
          "type" => "string",
          "description" => "The chat message content"
        },
        "message_type" => %{
          "type" => "string",
          "enum" => ["text", "command", "response", "error"],
          "description" => "The type of chat message"
        },
        "context" => %{
          "type" => "object",
          "description" => "Additional context for the message",
          "properties" => %{
            "thread_id" => %{
              "type" => "string",
              "description" => "ID of the conversation thread"
            },
            "reply_to" => %{
              "type" => "string",
              "description" => "ID of the message being replied to"
            },
            "metadata" => %{
              "type" => "object",
              "description" => "Additional metadata for the message"
            }
          }
        }
      },
      "required" => ["message", "message_type"]
    }
end

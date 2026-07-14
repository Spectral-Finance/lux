defmodule Lux.Prisms.Telegram.Processing.ReplyParser do
  @moduledoc """
  A prism for parsing Telegram message replies, managing reply state and routing.
  """

  use Lux.Prism,
    name: "Telegram Reply Parser",
    description: "Extracts information about the message being replied to",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "Telegram message object"
        }
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_reply: %{type: :boolean},
        replied_message_id: %{type: :integer},
        replied_user_id: %{type: :integer},
        replied_text: %{type: :string},
        route_to: %{type: :string},
        reply_state: %{type: :string},
        planned_reply_action: %{
          type: :object,
          properties: %{
            type: %{type: :string},
            reply_to_message_id: %{type: :integer}
          }
        }
      },
      required: ["is_reply"]
    }

  def handler(%{message: message}, _agent) when is_map(message) do
    message = stringify_keys(message)
    
    reply_to = message["reply_to_message"]
    
    if reply_to do
      {:ok, %{
        is_reply: true,
        replied_message_id: reply_to["message_id"],
        replied_user_id: get_in(reply_to, ["from", "id"]),
        replied_text: reply_to["text"] || reply_to["caption"],
        route_to: "reply_handler",
        reply_state: "in_context",
        planned_reply_action: %{
          type: "sendMessage",
          reply_to_message_id: reply_to["message_id"]
        }
      }}
    else
      {:ok, %{
        is_reply: false,
        replied_message_id: nil,
        replied_user_id: nil,
        replied_text: nil,
        route_to: "default_handler",
        reply_state: "none",
        planned_reply_action: nil
      }}
    end
  end
  
  def handler(%{"message" => message}, agent) when is_map(message) do
    handler(%{message: message}, agent)
  end
  
  def handler(_params, _agent) do
    {:error, "Missing required parameter: message"}
  end
  
  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end

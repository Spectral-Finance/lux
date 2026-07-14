defmodule Lux.Prisms.Telegram.Processing.MessageThreadParser do
  @moduledoc """
  A prism for parsing Telegram message thread (topic) information, routing it and returning planned reply actions.
  """

  use Lux.Prism,
    name: "Telegram Message Thread Parser",
    description: "Extracts thread and topic information from a Telegram message",
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
        is_topic_message: %{type: :boolean},
        message_thread_id: %{type: :integer},
        is_topic_action: %{type: :boolean},
        action_type: %{type: :string},
        thread_state: %{type: :string},
        route_to: %{type: :string},
        planned_reply_action: %{
          type: :object,
          properties: %{
            type: %{type: :string},
            target_thread_id: %{type: :integer}
          }
        }
      },
      required: ["is_topic_message"]
    }

  def handler(%{message: message}, _agent) when is_map(message) do
    message = stringify_keys(message)
    
    is_topic_message = Map.has_key?(message, "is_topic_message") and message["is_topic_message"] == true
    message_thread_id = message["message_thread_id"]
    
    # Topic actions:
    # forum_topic_created, forum_topic_edited, forum_topic_closed, forum_topic_reopened
    action_type = 
      cond do
        Map.has_key?(message, "forum_topic_created") -> "created"
        Map.has_key?(message, "forum_topic_edited") -> "edited"
        Map.has_key?(message, "forum_topic_closed") -> "closed"
        Map.has_key?(message, "forum_topic_reopened") -> "reopened"
        true -> nil
      end
      
    is_topic_action = action_type != nil
    
    thread_state = 
      case action_type do
        "closed" -> "closed"
        "created" -> "active"
        "reopened" -> "active"
        _ -> if message_thread_id, do: "active", else: "none"
      end
      
    route_to = if is_topic_action, do: "forum_management_handler", else: "thread_message_handler"
    
    planned_reply_action = if message_thread_id do
      %{type: "sendMessage", target_thread_id: message_thread_id}
    else
      nil
    end
    
    {:ok, %{
      is_topic_message: is_topic_message || message_thread_id != nil,
      message_thread_id: message_thread_id,
      is_topic_action: is_topic_action,
      action_type: action_type,
      thread_state: thread_state,
      route_to: route_to,
      planned_reply_action: planned_reply_action
    }}
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

defmodule Lux.Prisms.Telegram.Processing.ManageThread do
  @moduledoc """
  Extracts thread information (forum topics) from messages.
  """
  use Lux.Prism,
    name: "Manage Telegram Thread",
    description: "Extracts message thread/topic ID to support forum topics and threaded replies",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "The message object from Telegram update"
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
        topic_action_type: %{type: :string}
      },
      required: ["is_topic_message"]
    }

  def handler(params, _ctx) do
    message = Map.get(params, :message) || Map.get(params, "message")

    if is_map(message) do
      is_topic = Map.get(message, "is_topic_message", false)
      thread_id = Map.get(message, "message_thread_id")
      
      {is_action, action_type} = detect_topic_action(message)

      {:ok, %{
        is_topic_message: is_topic,
        message_thread_id: thread_id,
        is_topic_action: is_action,
        topic_action_type: action_type
      }}
    else
      {:error, "Invalid message object"}
    end
  end

  defp detect_topic_action(message) do
    cond do
      Map.has_key?(message, "forum_topic_created") -> {true, "created"}
      Map.has_key?(message, "forum_topic_edited") -> {true, "edited"}
      Map.has_key?(message, "forum_topic_closed") -> {true, "closed"}
      Map.has_key?(message, "forum_topic_reopened") -> {true, "reopened"}
      true -> {false, nil}
    end
  end
end

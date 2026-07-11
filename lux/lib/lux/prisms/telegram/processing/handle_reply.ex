defmodule Lux.Prisms.Telegram.Processing.HandleReply do
  @moduledoc """
  Manages reply logic for Telegram messages.
  """
  use Lux.Prism,
    name: "Handle Telegram Reply",
    description: "Extracts reply metadata to enable building threaded conversational responses",
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
        is_reply: %{type: :boolean},
        replied_message_id: %{type: :integer},
        replied_user_id: %{type: :integer},
        replied_text: %{type: :string}
      },
      required: ["is_reply"]
    }

  def handler(params, _ctx) do
    message = Map.get(params, :message) || Map.get(params, "message")

    if is_map(message) do
      if Map.has_key?(message, "reply_to_message") do
        reply = message["reply_to_message"]
        
        {:ok, %{
          is_reply: true,
          replied_message_id: Map.get(reply, "message_id"),
          replied_user_id: get_in(reply, ["from", "id"]),
          replied_text: Map.get(reply, "text") || Map.get(reply, "caption")
        }}
      else
        {:ok, %{
          is_reply: false,
          replied_message_id: nil,
          replied_user_id: nil,
          replied_text: nil
        }}
      end
    else
      {:error, "Invalid message object"}
    end
  end
end

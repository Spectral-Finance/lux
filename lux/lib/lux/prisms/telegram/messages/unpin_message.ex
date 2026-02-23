defmodule Lux.Prisms.Telegram.Messages.UnpinMessage do
  @moduledoc """
  A prism for unpinning a message in a Telegram chat.

  Removes the specified pinned message from the chat. If no message_id
  is provided, unpins the most recently pinned message.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /unpinChatMessage
  - The bot must be an administrator with can_pin_messages right
  - If message_id is omitted, unpins the most recently pinned message
  - Use UnpinAllMessages to clear all pinned messages at once

  ## Examples

      iex> UnpinMessage.handler(%{chat_id: 123_456_789, message_id: 42}, %{name: "Agent"})
      {:ok, %{unpinned: true, chat_id: 123_456_789, message_id: 42}}

      iex> UnpinMessage.handler(%{chat_id: 123_456_789}, %{name: "Agent"})
      {:ok, %{unpinned: true, chat_id: 123_456_789, message_id: nil}}
  """

  use Lux.Prism,
    name: "Unpin Telegram Message",
    description: "Unpins a message in a Telegram chat (requires admin rights). Unpins the most recently pinned if no message_id given.",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to unpin. If not specified, the most recent pinned message is unpinned."
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unpinned: %{type: :boolean, description: "Whether the message was unpinned successfully"},
        chat_id: %{description: "The chat where the message was unpinned"},
        message_id: %{type: [:integer, :null], description: "The message ID that was unpinned, or nil if most recent"}
      }
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _agent) do
    chat_id = params[:chat_id] || params["chat_id"]
    message_id = params[:message_id] || params["message_id"]

    body = %{chat_id: chat_id}
    body = if message_id, do: Map.put(body, :message_id, message_id), else: body

    with {:ok, _} <- Client.request(:post, "/unpinChatMessage", %{
      json: body,
      plug: params[:plug]
    }) do
      {:ok, %{
        unpinned: true,
        chat_id: chat_id,
        message_id: message_id
      }}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end

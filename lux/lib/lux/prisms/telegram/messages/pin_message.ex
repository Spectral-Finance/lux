defmodule Lux.Prisms.Telegram.Messages.PinMessage do
  @moduledoc """
  A prism for pinning a message in a Telegram chat.

  Pins a specified message in the chat. Works in groups, supergroups,
  and channels where the bot has the appropriate permissions.

  ## Implementation Details

  - Uses Telegram Bot API endpoint: POST /pinChatMessage
  - The bot must be an administrator with can_pin_messages right
  - Optionally suppresses the notification sent to chat members
  - Returns confirmation of the pinned message

  ## Examples

      iex> PinMessage.handler(%{chat_id: 123_456_789, message_id: 42}, %{name: "Agent"})
      {:ok, %{pinned: true, chat_id: 123_456_789, message_id: 42}}

      iex> PinMessage.handler(%{chat_id: 123_456_789, message_id: 42, disable_notification: true}, %{name: "Agent"})
      {:ok, %{pinned: true, chat_id: 123_456_789, message_id: 42}}
  """

  use Lux.Prism,
    name: "Pin Telegram Message",
    description: "Pins a message in a Telegram chat (requires admin rights)",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of the message to pin"
        },
        disable_notification: %{
          type: :boolean,
          description: "Pass True to pin the message silently. Users in the chat will not receive a notification for pinned messages."
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pinned: %{type: :boolean, description: "Whether the message was pinned successfully"},
        chat_id: %{description: "The chat where the message was pinned"},
        message_id: %{type: :integer, description: "The message ID that was pinned"}
      }
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, agent) do
    chat_id = params[:chat_id] || params["chat_id"]
    message_id = params[:message_id] || params["message_id"]
    disable_notification = params[:disable_notification] || params["disable_notification"] || false

    with {:ok, _} <- Client.request(:post, "/pinChatMessage", %{
      json: %{
        chat_id: chat_id,
        message_id: message_id,
        disable_notification: disable_notification
      },
      plug: params[:plug]
    }) do
      {:ok, %{
        pinned: true,
        chat_id: chat_id,
        message_id: message_id
      }}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end
end

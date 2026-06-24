defmodule Lux.Lenses.YouTube.Chat.SendChatMessage do
  @moduledoc """
  A lens for sending messages to YouTube live stream chat.

  Supports sending:
  - Regular text messages
  - Super Chat donations (with amount)
  - Super Sticker donations
  - Pin existing messages
  - Delete existing messages (moderator action)
  - Ban users (moderator action)

  ## Parameters

  - `broadcast_id`: YouTube broadcast ID (required)
  - `message`: Message text to send
  - `super_chat_amount_micros`: Donation amount in micros (1,000,000 = 1.00 USD)
  - `sticker_id`: Super Sticker ID (for sticker donations)
  - `message_id`: Target message ID (for pin/delete/ban actions)
  - `pin`: Whether to pin the message (requires moderator role)
  - `ban_user_id`: User ID to ban from chat (requires moderator role)

  ## Examples

      # Send a regular message
      iex> SendChatMessage.focus(%{
      ...>   broadcast_id: "abc123...",
      ...>   message: "Hello from Lux!"
      ...> })
      {:ok, %{message_id: "...", sent: true}}

      # Send a Super Chat
      iex> SendChatMessage.focus(%{
      ...>   broadcast_id: "abc123...",
      ...>   message: "Important announcement!",
      ...>   super_chat_amount_micros: 1000000
      ...> })
      {:ok, %{message_id: "...", amount: "$1.00"}}

      # Pin a message (moderator)
      iex> SendChatMessage.focus(%{
      ...>   broadcast_id: "abc123...",
      ...>   message_id: "msg123...",
      ...>   pin: true
      ...> })
      {:ok, %{pinned: true, message_id: "msg123..."}}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Send YouTube Chat Message",
    description: "Sends messages to a YouTube live stream chat (text, Super Chat, moderation)",
    url: "#{YouTube.api_base_url()}/liveChat/messages",
    method: :post,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "YouTube broadcast ID to send messages to",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        message: %{
          type: :string,
          description: "Message text to send (required for text/Super Chat messages)",
          minLength: 1,
          maxLength: 1000
        },
        super_chat_amount_micros: %{
          type: :integer,
          description: "Donation amount in micros (1,000,000 = $1.00 USD)",
          minimum: 0,
          maximum: 500000000
        },
        sticker_id: %{
          type: :string,
          description: "Super Sticker ID for sticker donations"
        },
        message_id: %{
          type: :string,
          description: "Target message ID (for pin/delete/ban moderation actions)"
        },
        pin: %{
          type: :boolean,
          description: "Pin the target message (requires moderator role)"
        },
        ban_user_id: %{
          type: :string,
          description: "User ID to ban from chat (requires moderator role)"
        },
        spam_user_id: %{
          type: :string,
          description: "User ID to mark as spam (requires moderator role)"
        },
        spam_message_id: %{
          type: :string,
          description: "Message ID to mark as spam (requires moderator role)"
        }
      },
      required: ["broadcast_id"]
    }

  @impl true
  def before_focus(params) do
    broadcast_id = params[:broadcast_id]

    body = build_body(params)
    part = build_part(params)

    %{
      url: "#{YouTube.api_base_url()}/liveChat/messages?liveChatId=#{broadcast_id}&part=#{part}",
      json: body
    }
  end

  @doc """
  Transforms the chat message send response.
  """
  @impl true
  def after_focus(%{
    "id" => message_id,
    "snippet" => snippet
  }) do
    chat_item = Map.get(snippet, "chatItemDetails", %{})

    Logger.info("Sent chat message to broadcast: #{message_id}")

    result = %{
      message_id: message_id,
      sent: true,
      message_type: Map.get(chat_item, "messageType", "simpleText"),
      is_super_chat: Map.get(chat_item, "isSuperChat"),
      is_pinned: Map.get(chat_item, "isPinned")
    }

    case Map.get(chat_item, "superChatDetails") do
      nil -> result
      details -> Map.put(result, :amount, Map.get(details, "userTransactionAmountDisplayString"))
    end
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp build_body(params) do
    body = %{
      snippet: %{
        liveChatId: params[:broadcast_id],
        type: "superChatEvent"
      }
    }

    body =
      if msg = Map.get(params, :message) do
        Map.put(body, :snippet, Map.put(body.snippet, :messageText, msg))
      else
        body
      end

    body =
      if amount = Map.get(params, :super_chat_amount_micros) do
        Map.put(body, :snippet, Map.put(body.snippet, :totalAmountMicros, amount))
      else
        body
      end

    body =
      if sticker = Map.get(params, :sticker_id) do
        Map.put(body, :snippet, Map.put(body.snippet, :surchargeStickerId, sticker))
      else
        body
      end

    body =
      if msg_id = Map.get(params, :message_id) do
        Map.put(body, :snippet, Map.put(body.snippet, :eventId, msg_id))
      else
        body
      end

    body =
      if Map.get(params, :pin) do
        Map.put(body, :snippet, Map.put(body.snippet, :isPinned, true))
      else
        body
      end

    body =
      if ban_id = Map.get(params, :ban_user_id) do
        Map.put(body, :snippet, Map.put(body.snippet, :banUserDetails, %{userId: ban_id}))
      else
        body
      end

    body =
      if spam_id = Map.get(params, :spam_user_id) do
        Map.put(body, :snippet, Map.put(body.snippet, :spamUserDetails, %{userId: spam_id}))
      else
        body
      end

    body =
      if spam_msg_id = Map.get(params, :spam_message_id) do
        Map.put(body, :snippet, Map.put(body.snippet, :spamEventId, spam_msg_id))
      else
        body
      end

    body
  end

  defp build_part(params) do
    case {Map.get(params, :message), Map.get(params, :super_chat_amount_micros)} do
      {nil, nil} -> "id,snippet"
      _ -> "id,snippet"
    end
  end
end

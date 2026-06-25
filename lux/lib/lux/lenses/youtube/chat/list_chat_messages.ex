defmodule Lux.Lenses.YouTube.Chat.ListChatMessages do
  @moduledoc """
  A lens for retrieving real-time chat messages from YouTube live streams.

  Provides access to live chat messages including:
  - Message text and sender information
  - Super Chat and Super Sticker data
  - Member messages and pinned messages
  - Message timestamps and continuation tokens

  ## Parameters

  - `broadcast_id`: YouTube broadcast ID (required)
  - `part`: Resource parts to include (snippet, id)
  - `max_results`: Max messages to return (1-100, default 20)
  - `page_token`: Continuation token for pagination
  - `published_after`: ISO 8601 timestamp to filter messages after

  ## Examples

      # Get recent chat messages
      iex> ListChatMessages.focus(%{
      ...>   broadcast_id: "abc123..."
      ...> })
      {:ok, [%{sender: "...", message: "...", super_chat: ..., ...}]}

      # Paginate through chat history
      iex> ListChatMessages.focus(%{
      ...>   broadcast_id: "abc123...",
      ...>   page_token: "CAAQAw"
      ...> })
      {:ok, [...]}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Chat Messages",
    description: "Retrieves real-time chat messages from a YouTube live broadcast",
    url: "#{YouTube.api_base_url()}/liveChat/messages",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "YouTube broadcast ID to fetch chat messages from",
          pattern: "^[a-zA-Z0-9_-]+$"
        },
        part: %{
          type: :string,
          description: "Resource parts to include",
          default: "snippet",
          enum: ["snippet", "id", "snippet,id"]
        },
        max_results: %{
          type: :integer,
          description: "Max messages to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        page_token: %{
          type: :string,
          description: "Continuation token from a previous response"
        },
        published_after: %{
          type: :string,
          description: "ISO 8601 timestamp to filter messages published after"
        }
      },
      required: ["broadcast_id"]
    }

  @impl true
  def before_focus(params) do
    broadcast_id = params[:broadcast_id]
    part = Map.get(params, :part, "snippet")
    max_results = Map.get(params, :max_results, 20)

    query_params = [
      {"part", part},
      {"maxResults", max_results},
      {"liveChatId", broadcast_id}
    ]

    query_params =
      query_params
      |> maybe_add("pageToken", Map.get(params, :page_token))
      |> maybe_add("publishedAfter", Map.get(params, :published_after))

    %{url: "#{YouTube.api_base_url()}/liveChat/messages?#{URI.encode_query(query_params)}"}
  end

  @doc """
  Transforms chat messages into a clean format with sender info and message content.
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    messages = Enum.map(items, &transform_message/1)

    result = %{messages: messages}

    next_token = Enum.find_value(items, nil, fn item ->
      case item["nextPageToken"] do
        nil -> nil
        token -> token
      end
    end)

    # Check for continuation token at top level or in items
    result =
      case Enum.find(items, fn item ->
             snippet = Map.get(item, "snippet", %{})
             Map.has_key?(snippet, "continuation")
           end) do
        nil -> result
        _ -> result
      end

    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}), do: {:error, message}
  def after_focus(%{"error" => error}), do: {:error, error}

  defp transform_message(item) do
    snippet = item["snippet"] || %{}

    message_sender = Map.get(snippet, "messageSenderDetails") || %{}
    chat_item_details = Map.get(snippet, "chatItemDetails") || %{}
    super_chat_details = Map.get(snippet, "superChatDetails") || %{}
    member_details = Map.get(snippet, "memberDetails") || %{}
    display_message = Map.get(snippet, "displayMessage", "")

    %{
      id: item["id"],
      message: display_message,
      sender_id: Map.get(message_sender, "channelId"),
      sender_name: Map.get(message_sender, "displayName"),
      sender_thumbnail: Map.get(message_sender, "thumbnailDetails", %{}) |> Map.get("externalThumbnailUrl"),
      sender_is_owner: Map.get(message_sender, "isOwner"),
      sender_is_moderator: Map.get(message_sender, "isModerator"),
      sender_is_member: Map.get(message_sender, "isMember"),
      sent_at: snippet["publishedAt"],
      updated_at: snippet["updatedAt"],
      message_type: Map.get(chat_item_details, "messageType", "simpleText"),
      is_super_chat: Map.get(chat_item_details, "isSuperChat"),
      is_super_sticker: Map.get(chat_item_details, "isSuperSticker"),
      is_member_only: Map.get(chat_item_details, "isMemberOnly"),
      is_pinned: Map.get(chat_item_details, "isPinned"),
      pinned_reason: Map.get(chat_item_details, "pinnedReason"),
      super_chat_amount: Map.get(super_chat_details, "userTransactionAmountDisplayString"),
      super_chat_currency: Map.get(super_chat_details, "userTransactionAmountMicros"),
      super_chat_color_scheme: Map.get(super_chat_details, "colorScheme"),
      sticker_thumbnail_urls: Map.get(super_chat_details, "stickerThumbnails"),
      member_level: Map.get(member_details, "memberLevel"),
      duration_minutes: Map.get(member_details, "durationMinutes")
    }
  end

  defp maybe_add(params, _key, nil), do: params
  defp maybe_add(params, key, value), do: params ++ [{Atom.to_string(key), to_string(value)}]
end

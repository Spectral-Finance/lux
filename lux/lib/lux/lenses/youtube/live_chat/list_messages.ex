defmodule Lux.Lenses.YouTube.LiveChat.ListMessages do
  @moduledoc """
  A lens for retrieving live chat messages from a YouTube live stream.

  Supports real-time chat monitoring with polling via page tokens.
  Returns messages with author details, message type, and timestamps.

  ## Authentication

  Requires OAuth2 token for accessing live chat data.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> ListMessages.focus(%{
      ...>   live_chat_id: "EwAB..."
      ...> })
      {:ok, %{
        messages: [
          %{
            id: "LCC...",
            author_name: "viewer123",
            author_channel_id: "UCxxx",
            text: "Hello from the chat!",
            type: "textMessageEvent",
            published_at: "2024-01-15T18:05:23.000Z",
            is_moderator: false,
            is_verified: false
          }
        ],
        next_page_token: "abc...",
        polling_interval_ms: 5000,
        offline_at: nil
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Live Chat Messages",
    description: "Retrieves live chat messages from a YouTube stream with polling support",
    url: "https://www.googleapis.com/youtube/v3/liveChat/messages",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.oauth_auth(),
    schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{
          type: :string,
          description: "The live chat ID (from broadcast's snippet.liveChatId)"
        },
        page_token: %{
          type: :string,
          description: "Pagination token for fetching newer messages"
        },
        max_results: %{
          type: :integer,
          description: "Maximum messages to return (200 max)",
          minimum: 1,
          maximum: 200
        }
      },
      required: ["live_chat_id"]
    }

  @impl true
  def before_focus(params) do
    live_chat_id = params["live_chat_id"] || params[:live_chat_id]
    max_results = params["max_results"] || params[:max_results] || 200

    query = %{
      "liveChatId" => live_chat_id,
      "part" => "snippet,authorDetails",
      "maxResults" => max_results
    }

    query =
      if token = params["page_token"] || params[:page_token] do
        Map.put(query, "pageToken", token)
      else
        query
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => items} = data) do
    messages = Enum.map(items, &transform_message/1)

    {:ok, %{
      messages: messages,
      next_page_token: data["nextPageToken"],
      polling_interval_ms: data["pollingIntervalMillis"],
      offline_at: data["offlineAt"],
      page_info: data["pageInfo"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_message(item) do
    snippet = item["snippet"] || %{}
    author = item["authorDetails"] || %{}

    msg_details =
      case snippet["type"] do
        "textMessageEvent" -> get_in(snippet, ["textMessageDetails", "messageText"])
        "superChatEvent" ->
          super_chat = snippet["superChatDetails"] || %{}
          "[$#{super_chat["amountDisplayString"]}] #{super_chat["userComment"]}"
        "superStickerEvent" -> "[Super Sticker]"
        "memberMilestoneChatEvent" -> "[Member Milestone]"
        "newSponsorEvent" -> "[New Member]"
        _ -> nil
      end

    %{
      id: item["id"],
      type: snippet["type"],
      live_chat_id: snippet["liveChatId"],
      author_name: author["displayName"],
      author_channel_id: author["channelId"],
      author_channel_url: author["channelUrl"],
      author_profile_image_url: author["profileImageUrl"],
      text: msg_details,
      published_at: snippet["publishedAt"],
      is_moderator: author["isChatModerator"],
      is_owner: author["isChatOwner"],
      is_sponsor: author["isChatSponsor"],
      is_verified: author["isVerified"]
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end

defmodule Lux.Lenses.YouTube.GetLiveChat do
  @moduledoc """
  A lens for retrieving live chat messages for a YouTube live broadcast.
  Supports pagination via `nextPageToken` and returns `pollingIntervalMillis`.
  """

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.Utils

  use Lux.Lens,
    name: "Get YouTube Live Chat Messages",
    description: "Retrieves live chat messages for a YouTube live broadcast",
    url: "https://www.googleapis.com/youtube/v3/liveChat/messages",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        liveChatId: %{
          type: :string,
          description: "The live chat ID to retrieve messages for"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,authorDetails"
        },
        pageToken: %{
          type: :string,
          description: "Token for the next page of results"
        },
        maxResults: %{
          type: :integer,
          description: "Maximum number of messages to return",
          default: 500
        }
      },
      required: ["liveChatId"]
    }

  def before_focus(params) do
    params
    |> Map.delete(:access_token)
    |> Map.delete("access_token")
    |> Map.delete(:plug)
    |> Map.delete("plug")
    |> Utils.to_youtube_query_params()
  end

  @impl true
  def after_focus(body) do
    messages =
      case body["items"] do
        items when is_list(items) ->
          Enum.map(items, fn item ->
            snippet = item["snippet"] || %{}
            author = item["authorDetails"] || %{}
            %{
              id: item["id"],
              type: snippet["type"],
              published_at: snippet["publishedAt"],
              text: get_in(snippet, ["textMessageDetails", "messageText"]),
              author_channel_id: author["channelId"],
              display_name: author["displayName"],
              profile_image_url: author["profileImageUrl"],
              is_chat_owner: author["isChatOwner"],
              is_chat_sponsor: author["isChatSponsor"],
              is_chat_moderator: author["isChatModerator"]
            }
          end)
        _ ->
          []
      end

    {:ok,
     %{
       messages: messages,
       next_page_token: body["nextPageToken"],
       polling_interval_millis: body["pollingIntervalMillis"] || 5000,
       offline_at: body["offlineAt"]
     }}
  end
end

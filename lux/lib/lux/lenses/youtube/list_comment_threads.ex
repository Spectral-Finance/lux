defmodule Lux.Lenses.YouTube.ListCommentThreads do
  @moduledoc """
  A lens for listing YouTube comment threads for a video or channel.
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Comment Threads",
    description: "Fetches comment threads for a specific YouTube video or channel",
    url: "https://www.googleapis.com/youtube/v3/commentThreads",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The YouTube video ID"
        },
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID"
        },
        part: %{
          type: :string,
          description: "API resource parts to include",
          default: "snippet,replies"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of items to return",
          default: 20
        },
        page_token: %{
          type: :string,
          description: "Token for the next page of results"
        }
      }
    }

  def before_focus(params) do
    params =
      params
      |> Map.delete(:access_token)
      |> Map.delete("access_token")
      |> Map.delete(:plug)
      |> Map.delete("plug")
      |> Lux.Integrations.YouTube.Utils.to_youtube_query_params()

    params
  end

  @impl true
  def after_focus(%{"items" => items} = response) when is_list(items) do
    comments =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}
        top_level = snippet["topLevelComment"] || %{}
        top_level_snippet = top_level["snippet"] || %{}

        %{
          id: item["id"],
          video_id: snippet["videoId"],
          channel_id: snippet["channelId"],
          text_display: top_level_snippet["textDisplay"],
          text_original: top_level_snippet["textOriginal"],
          author_display_name: top_level_snippet["authorDisplayName"],
          author_channel_id: get_in(top_level_snippet, ["authorChannelId", "value"]),
          like_count: top_level_snippet["likeCount"],
          published_at: top_level_snippet["publishedAt"],
          updated_at: top_level_snippet["updatedAt"],
          total_reply_count: snippet["totalReplyCount"]
        }
      end)

    result = %{comments: comments}
    result = if response["nextPageToken"], do: Map.put(result, :next_page_token, response["nextPageToken"]), else: result

    {:ok, result}
  end

  def after_focus(%{"error" => %{"message" => message}}) do
    {:error, %{"message" => message}}
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end

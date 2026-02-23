defmodule Lux.Lenses.YouTube.Community.ListCommentThreads do
  @moduledoc """
  A lens for listing YouTube comment threads on a video.

  Fetches top-level comment threads using the YouTube Data API v3,
  including reply counts and engagement metrics. Useful for:
  - Community engagement analysis
  - Comment moderation workflows
  - Subscriber interaction tracking

  ## Examples

      iex> ListCommentThreads.focus(%{video_id: "dQw4w9WgXcQ"})
      {:ok, %{
        threads: [
          %{
            id: "thread_id",
            video_id: "dQw4w9WgXcQ",
            text: "Great video!",
            author: "TestUser",
            like_count: 42,
            reply_count: 3,
            published_at: "2024-01-01T00:00:00Z",
            can_reply: true
          }
        ],
        count: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Comment Threads",
    description: "Lists top-level comment threads on a YouTube video with engagement metrics",
    url: "https://www.googleapis.com/youtube/v3/commentThreads",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "The ID of the YouTube video to fetch comment threads for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of comment threads to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        order: %{
          type: :string,
          description: "Sort order: 'time' for newest first, 'relevance' for top comments",
          enum: ["time", "relevance"],
          default: "relevance"
        },
        page_token: %{
          type: :string,
          description: "Token for retrieving the next page of results"
        }
      },
      required: ["video_id"]
    }

  @impl true
  def before_focus(params) do
    video_id = params["video_id"] || params[:video_id]
    max_results = params["max_results"] || params[:max_results] || 20
    order = params["order"] || params[:order] || "relevance"

    query = %{
      "videoId" => video_id,
      "part" => "snippet,replies",
      "maxResults" => max_results,
      "order" => order
    }

    query =
      case params["page_token"] || params[:page_token] do
        nil -> query
        token -> Map.put(query, "pageToken", token)
      end

    {:ok, query}
  end

  @impl true
  def after_focus(%{"items" => items}) when is_list(items) do
    threads =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}
        top_comment = get_in(snippet, ["topLevelComment", "snippet"]) || %{}

        %{
          id: item["id"],
          video_id: snippet["videoId"],
          text: top_comment["textDisplay"],
          author: top_comment["authorDisplayName"],
          like_count: top_comment["likeCount"] || 0,
          reply_count: snippet["totalReplyCount"] || 0,
          published_at: top_comment["publishedAt"],
          can_reply: snippet["canReply"] || false
        }
      end)

    {:ok, %{threads: threads, count: length(threads)}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end

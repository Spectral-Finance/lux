defmodule Lux.Lenses.YouTube.Community.ListComments do
  @moduledoc """
  A lens for listing reply comments within a YouTube comment thread.

  Fetches replies to a top-level comment thread using the YouTube Data API v3.
  Useful for:
  - Tracking reply conversations
  - Fan interaction analysis
  - Cross-platform promotion monitoring

  ## Examples

      iex> ListComments.focus(%{parent_id: "Ugw_comment_thread_id"})
      {:ok, %{
        comments: [
          %{
            id: "reply_id",
            parent_id: "Ugw_comment_thread_id",
            text: "Thanks for the reply!",
            author: "ReplyUser",
            like_count: 5,
            published_at: "2024-01-02T00:00:00Z",
            updated_at: "2024-01-02T00:00:00Z"
          }
        ],
        count: 1
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "List YouTube Comments",
    description: "Lists reply comments within a YouTube comment thread",
    url: "https://www.googleapis.com/youtube/v3/comments",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        parent_id: %{
          type: :string,
          description: "The ID of the comment thread to fetch replies for"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of replies to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 20
        },
        page_token: %{
          type: :string,
          description: "Token for retrieving the next page of results"
        }
      },
      required: ["parent_id"]
    }

  @impl true
  def before_focus(params) do
    parent_id = params["parent_id"] || params[:parent_id]
    max_results = params["max_results"] || params[:max_results] || 20

    query = %{
      "parentId" => parent_id,
      "part" => "snippet",
      "maxResults" => max_results
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
    comments =
      Enum.map(items, fn item ->
        snippet = item["snippet"] || %{}

        %{
          id: item["id"],
          parent_id: snippet["parentId"],
          text: snippet["textDisplay"],
          author: snippet["authorDisplayName"],
          like_count: snippet["likeCount"] || 0,
          published_at: snippet["publishedAt"],
          updated_at: snippet["updatedAt"]
        }
      end)

    {:ok, %{comments: comments, count: length(comments)}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end
end

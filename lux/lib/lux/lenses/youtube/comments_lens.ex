defmodule Lux.Lenses.Youtube.CommentsLens do
  @moduledoc """
  Lens for fetching YouTube video comments via the YouTube Data API v3.

  Retrieves top-level comments and their replies for sentiment analysis
  and audience engagement insights.

  ## Example

      iex> Lux.Lenses.Youtube.CommentsLens.focus(%{video_id: "dQw4w9WgXcQ", max_results: 50})
      {:ok, %{video_id: "...", comments: [...], total_count: 123}}
  """

  use Lux.Lens,
    name: "YouTube Comments",
    description: "Fetches YouTube video comments and replies for engagement analysis",
    url: "https://www.googleapis.com/youtube/v3/commentThreads",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :query_param,
      param_name: "key",
      env_var: "YOUTUBE_API_KEY"
    },
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of comments to fetch (1-100)",
          default: 50
        },
        order: %{
          type: :string,
          description: "Sort order for comments",
          default: "relevance",
          enum: ["relevance", "time"]
        },
        text_format: %{
          type: :string,
          description: "Format of comment text",
          default: "plainText",
          enum: ["plainText", "html"]
        }
      },
      required: ["video_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        total_count: %{type: :integer},
        page_token: %{type: :string},
        comments: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              comment_id: %{type: :string},
              author: %{type: :string},
              author_channel_id: %{type: :string},
              text: %{type: :string},
              published_at: %{type: :string},
              updated_at: %{type: :string},
              like_count: %{type: :integer},
              reply_count: %{type: :integer},
              replies: %{type: :array}
            }
          }
        }
      }
    }

  @doc """
  Fetches comments for a specific video.
  """
  def focus(params) do
    video_id = Map.get(params, :video_id, params["video_id"])
    max_results = Map.get(params, :max_results, params["max_results"] || 50)
    order = Map.get(params, :order, params["order"] || "relevance")
    text_format = Map.get(params, :text_format, params["text_format"] || "plainText")
    page_token = Map.get(params, :page_token, params["page_token"])

    query_params = %{
      "part" => "snippet,replies",
      "videoId" => video_id,
      "maxResults" => max_results,
      "order" => order,
      "textFormat" => text_format
    }
    |> Enum.into(%{}, fn {k, v} -> {k, v} end)
    |> Map.reject(fn {_k, v} -> is_nil(v) end)

    with {:ok, response} <- make_request(query_params: query_params),
         {:ok, data} <- parse_response(response, video_id) do
      {:ok, data}
    end
  end

  defp make_request(opts) do
    base_url = Keyword.get(opts, :base_url, @url)
    query_params = Keyword.get(opts, :query_params, %{})

    case HTTPoison.get("#{base_url}?#{URI.encode_query(query_params)}", get_headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "API error #{status}: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  defp get_headers do
    [{"Content-Type", "application/json"}]
  end

  defp parse_response(body, video_id) do
    case Jason.decode(body) do
      {:ok, %{"items" => items, "pageInfo" => %{"totalResults" => total}}} ->
        comments = Enum.map(items, &parse_comment(&1))
        page_token = Map.get(body |> Jason.decode!(), "nextPageToken")

        data = %{
          video_id: video_id,
          total_count: total,
          page_token: page_token,
          comments: comments
        }

        {:ok, data}

      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, "YouTube API error: #{message}"}

      {:ok, _} ->
        {:error, "Unexpected response format"}

      {:error, error} ->
        {:error, "JSON parse error: #{inspect(error)}"}
    end
  end

  defp parse_comment(item) do
    snippet = get_in(item, ["snippet", "topLevelComment", "snippet"]) || %{}
    replies = get_in(item, ["replies", "comments"]) || []

    %{
      comment_id: get_in(item, ["id"]),
      author: snippet["authorDisplayName"],
      author_channel_id: get_in(snippet, ["authorChannelId", "value"]),
      text: snippet["textDisplay"] || snippet["textOriginal"] || "",
      published_at: snippet["publishedAt"],
      updated_at: snippet["updatedAt"],
      like_count: snippet["likeCount"] || 0,
      reply_count: length(replies),
      replies: Enum.map(replies, &parse_reply/1)
    }
  end

  defp parse_reply(reply) do
    snippet = reply["snippet"] || %{}
    %{
      comment_id: reply["id"],
      author: snippet["authorDisplayName"],
      text: snippet["textDisplay"] || snippet["textOriginal"] || "",
      published_at: snippet["publishedAt"],
      like_count: snippet["likeCount"] || 0
    }
  end
end

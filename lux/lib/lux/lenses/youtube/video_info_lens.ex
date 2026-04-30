defmodule Lux.Lenses.Youtube.VideoInfoLens do
  @moduledoc """
  Lens for fetching YouTube video information via the YouTube Data API v3.

  Retrieves comprehensive video metadata including title, description,
  statistics, tags, category, and content details.

  ## Example

      iex> Lux.Lenses.Youtube.VideoInfoLens.focus(%{video_id: "dQw4w9WgXcQ"})
      {:ok, %{video_id: "dQw4w9WgXcQ", title: "...", views: 1234, ...}}
  """

  use Lux.Lens,
    name: "YouTube Video Info",
    description: "Fetches comprehensive YouTube video metadata including statistics, tags, and content details",
    url: "https://www.googleapis.com/youtube/v3/videos",
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
          description: "YouTube video ID (e.g., 'dQw4w9WgXcQ')"
        },
        part: %{
          type: :string,
          description: "Comma-separated list of video resource parts",
          default: "snippet,statistics,contentDetails,status,player"
        },
        locale: %{
          type: :string,
          description: "ISO 639-1 language code for localized metadata",
          default: "en"
        }
      },
      required: ["video_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        title: %{type: :string},
        description: %{type: :string},
        published_at: %{type: :string},
        channel_id: %{type: :string},
        channel_title: %{type: :string},
        tags: %{type: :array, items: %{type: :string}},
        category_id: %{type: :string},
        default_language: %{type: :string},
        duration: %{type: :string},
        definition: %{type: :string},
        caption: %{type: :string},
        view_count: %{type: :integer},
        like_count: %{type: :integer},
        comment_count: %{type: :integer},
        favorite_count: %{type: :integer},
        privacy_status: %{type: :string},
        embeddable: %{type: :boolean},
        licensed_content: %{type: :boolean}
      }
    }

  @doc """
  Fetches video information from YouTube API.
  """
  def focus(params) do
    video_id = Map.get(params, :video_id, params["video_id"])
    part = Map.get(params, :part, params["part"] || "snippet,statistics,contentDetails,status")
    locale = Map.get(params, :locale, params["locale"] || "en")

    query_params = %{
      "id" => video_id,
      "part" => part,
      "hl" => locale
    }

    with {:ok, response} <- make_request(query_params: query_params),
         {:ok, data} <- parse_response(response) do
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

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, %{"items" => [%{"snippet" => snippet, "statistics" => stats} = item]}} ->
        data = %{
          video_id: item["id"],
          title: snippet["title"],
          description: snippet["description"],
          published_at: snippet["publishedAt"],
          channel_id: snippet["channelId"],
          channel_title: snippet["channelTitle"],
          tags: snippet["tags"] || [],
          category_id: snippet["categoryId"],
          default_language: snippet["defaultLanguage"],
          duration: item["contentDetails"]["duration"],
          definition: item["contentDetails"]["definition"],
          caption: item["contentDetails"]["caption"],
          view_count: parse_integer(stats["viewCount"]),
          like_count: parse_integer(stats["likeCount"]),
          comment_count: parse_integer(stats["commentCount"]),
          favorite_count: parse_integer(stats["favoriteCount"]),
          privacy_status: item["status"]["privacyStatus"],
          embeddable: item["status"]["embeddable"],
          licensed_content: item["status"]["licensedContent"]
        }

        {:ok, data}

      {:ok, %{"items" => []}} ->
        {:error, "Video not found"}

      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, "YouTube API error: #{message}"}

      {:ok, _} ->
        {:error, "Unexpected response format"}

      {:error, error} ->
        {:error, "JSON parse error: #{inspect(error)}"}
    end
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(val) when is_integer(val), do: val
  defp parse_integer(val) when is_binary(val), do: String.to_integer(val)
end

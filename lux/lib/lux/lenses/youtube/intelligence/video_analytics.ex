defmodule Lux.Lenses.YouTube.Intelligence.VideoAnalytics do
  @moduledoc """
  Lens for collecting and analyzing YouTube video performance metrics.

  Fetches detailed analytics including views, engagement rates, watch time,
  audience retention, and traffic sources for a given video or channel.
  """

  alias Lux.Integrations.YouTube.Client

  @metrics ~w(views likes comments shares estimatedMinutesWatched averageViewDuration subscribersGained)

  def focus(params, _opts \\ []) do
    action = params[:action] || params["action"] || "video_stats"
    plug = params[:plug]

    case action do
      "video_stats" -> fetch_video_stats(params, plug)
      "channel_stats" -> fetch_channel_stats(params, plug)
      "top_videos" -> fetch_top_videos(params, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  def supported_metrics, do: @metrics

  defp fetch_video_stats(params, plug) do
    video_id = params[:video_id] || params["video_id"]
    auth = params[:auth] || params["auth"]

    opts = build_opts(auth, plug)

    case Client.request(:get, "https://www.googleapis.com/youtube/v3/videos", Map.merge(opts, %{
           params: %{part: "statistics,contentDetails,snippet", id: video_id}
         })) do
      {:ok, %{status: 200, body: body}} ->
        case get_in(body, ["items"]) do
          [item | _] -> {:ok, parse_video_stats(item)}
          _ -> {:error, "Video not found"}
        end

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_channel_stats(params, plug) do
    channel_id = params[:channel_id] || params["channel_id"]
    auth = params[:auth] || params["auth"]

    opts = build_opts(auth, plug)

    case Client.request(:get, "https://www.googleapis.com/youtube/v3/channels", Map.merge(opts, %{
           params: %{part: "statistics,snippet,contentDetails", id: channel_id}
         })) do
      {:ok, %{status: 200, body: body}} ->
        case get_in(body, ["items"]) do
          [item | _] -> {:ok, parse_channel_stats(item)}
          _ -> {:error, "Channel not found"}
        end

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_top_videos(params, plug) do
    channel_id = params[:channel_id] || params["channel_id"]
    auth = params[:auth] || params["auth"]
    max_results = params[:max_results] || params["max_results"] || 10

    opts = build_opts(auth, plug)

    case Client.request(:get, "https://www.googleapis.com/youtube/v3/search", Map.merge(opts, %{
           params: %{
             part: "snippet",
             channelId: channel_id,
             order: "viewCount",
             maxResults: max_results,
             type: "video"
           }
         })) do
      {:ok, %{status: 200, body: body}} ->
        videos = Enum.map(body["items"] || [], &parse_search_result/1)
        {:ok, %{videos: videos, total: body["pageInfo"]["totalResults"]}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_video_stats(item) do
    stats = item["statistics"] || %{}
    snippet = item["snippet"] || %{}
    content = item["contentDetails"] || %{}

    %{
      video_id: item["id"],
      title: snippet["title"],
      published_at: snippet["publishedAt"],
      duration: content["duration"],
      views: parse_int(stats["viewCount"]),
      likes: parse_int(stats["likeCount"]),
      comments: parse_int(stats["commentCount"]),
      engagement_rate: calculate_engagement(stats),
      tags: snippet["tags"] || [],
      category_id: snippet["categoryId"]
    }
  end

  defp parse_channel_stats(item) do
    stats = item["statistics"] || %{}
    snippet = item["snippet"] || %{}

    %{
      channel_id: item["id"],
      title: snippet["title"],
      subscribers: parse_int(stats["subscriberCount"]),
      total_views: parse_int(stats["viewCount"]),
      video_count: parse_int(stats["videoCount"]),
      avg_views_per_video: safe_div(parse_int(stats["viewCount"]), parse_int(stats["videoCount"]))
    }
  end

  defp parse_search_result(item) do
    %{
      video_id: get_in(item, ["id", "videoId"]),
      title: get_in(item, ["snippet", "title"]),
      published_at: get_in(item, ["snippet", "publishedAt"]),
      description: get_in(item, ["snippet", "description"])
    }
  end

  defp calculate_engagement(stats) do
    views = parse_int(stats["viewCount"])
    likes = parse_int(stats["likeCount"])
    comments = parse_int(stats["commentCount"])

    if views > 0 do
      Float.round((likes + comments) / views * 100, 2)
    else
      0.0
    end
  end

  defp safe_div(_, 0), do: 0
  defp safe_div(a, b), do: div(a, b)

  defp parse_int(nil), do: 0
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n) when is_integer(n), do: n

  defp build_opts(auth, plug) do
    opts = %{}
    opts = if auth, do: Map.put(opts, :auth, auth), else: opts
    if plug, do: Map.put(opts, :plug, plug), else: opts
  end
end

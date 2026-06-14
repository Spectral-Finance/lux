defmodule Lux.Prisms.YouTube.YouTubeAnalyticsPrism do
  @moduledoc """
  A prism for fetching YouTube channel and video analytics.
  """

  use Lux.Prism,
    name: "YouTube Analytics",
    description: "Fetches YouTube channel and video analytics via YouTube Analytics API",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["channel_stats", "video_stats", "top_videos", "retention_analysis", "performance_benchmark", "roi_tracking", "automated_report"]},
        video_id: %{type: :string},
        start_date: %{type: :string},
        end_date: %{type: :string},
        days: %{type: :integer, default: 30},
        max_results: %{type: :integer, default: 10}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        stats: %{type: :object},
        videos: %{type: :array}
      },
      required: ["status"]
    }

  require Logger

  @api "https://www.googleapis.com/youtube/v3"

  def handler(input, _ctx) do
    with {:ok, api_key} <- get_api_key() do
      case input.action do
        "channel_stats"         -> get_channel_stats(api_key)
        "video_stats"           -> get_video_stats(api_key, input.video_id)
        "top_videos"            -> get_top_videos(api_key, input)
        "retention_analysis"    -> get_retention_analysis(api_key, input)
        "performance_benchmark" -> get_performance_benchmark(api_key, input)
        "roi_tracking"          -> get_roi_tracking(api_key, input)
        "automated_report"      -> get_automated_report(api_key, input)
        _                       -> {:error, "Unknown action: #{input.action}"}
      end
    end
  end

  defp get_api_key do
    key = Lux.Config.get(:youtube_api_key) || System.get_env("YOUTUBE_API_KEY")
    if key, do: {:ok, key}, else: {:error, "YouTube API key not configured"}
  rescue
    _ -> {:error, "YouTube API key not configured"}
  end

  defp get_channel_stats(api_key) do
    case Req.get("#{@api}/channels",
      params: %{part: "snippet,statistics,contentDetails", mine: true, key: api_key}
    ) do
      {:ok, %{status: 200, body: %{"items" => [channel | _]}}} ->
        stats = channel["statistics"] || %{}
        {:ok, %{
          status: "success",
          stats: %{
            channel_id: channel["id"],
            title: get_in(channel, ["snippet", "title"]),
            subscribers: stats["subscriberCount"],
            total_views: stats["viewCount"],
            video_count: stats["videoCount"],
            description: get_in(channel, ["snippet", "description"])
          }
        }}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp get_video_stats(api_key, video_id) do
    case Req.get("#{@api}/videos",
      params: %{part: "snippet,statistics,status", id: video_id, key: api_key}
    ) do
      {:ok, %{status: 200, body: %{"items" => [video | _]}}} ->
        stats = video["statistics"] || %{}
        {:ok, %{
          status: "success",
          stats: %{
            video_id: video["id"],
            title: get_in(video, ["snippet", "title"]),
            views: stats["viewCount"],
            likes: stats["likeCount"],
            comments: stats["commentCount"],
            published_at: get_in(video, ["snippet", "publishedAt"])
          }
        }}
      {:ok, %{status: 200}} -> {:error, "Video not found"}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp get_top_videos(api_key, input) do
    case Req.get("#{@api}/videos",
      params: %{
        part: "snippet,statistics",
        chart: "mostPopular",
        maxResults: Map.get(input, :max_results, 10),
        key: api_key
      }
    ) do
      {:ok, %{status: 200, body: body}} ->
        videos = Enum.map(body["items"] || [], fn v ->
          %{
            id: v["id"],
            title: get_in(v, ["snippet", "title"]),
            views: get_in(v, ["statistics", "viewCount"]),
            likes: get_in(v, ["statistics", "likeCount"])
          }
        end)
        {:ok, %{status: "success", videos: videos}}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp get_retention_analysis(api_key, input) do
    video_id = Map.get(input, :video_id, "")
    case Req.get("#{@api}/videos",
      params: %{part: "statistics,contentDetails", id: video_id, key: api_key}
    ) do
      {:ok, %{status: 200, body: %{"items" => [video | _]}}} ->
        stats = video["statistics"] || %{}
        views = String.to_integer(stats["viewCount"] || "0")
        likes = String.to_integer(stats["likeCount"] || "0")
        comments = String.to_integer(stats["commentCount"] || "0")
        retention_score = Float.round((likes + comments) / max(views, 1) * 100, 2)
        {:ok, %{
          status: "success",
          stats: %{
            video_id: video_id,
            views: views,
            likes: likes,
            comments: comments,
            retention_score: retention_score,
            recommendation: if(retention_score > 5, do: "Good retention", else: "Improve content hooks")
          }
        }}
      {:ok, %{status: s, body: b}} -> {:error, "Error #{s}: #{inspect(b)}"}
      {:error, r} -> {:error, inspect(r)}
    end
  end

  defp get_performance_benchmark(api_key, _input) do
    with {:ok, channel} <- get_channel_stats(api_key) do
      subs = String.to_integer(to_string(channel.stats.subscribers || "0"))
      views = String.to_integer(to_string(channel.stats.total_views || "0"))
      videos = String.to_integer(to_string(channel.stats.video_count || "1"))
      avg_views = div(views, max(videos, 1))
      benchmark_score = Float.round(min(subs / 1000, 40) + min(views / 10_000, 40) + min(videos / 10, 20), 1)
      {:ok, %{
        status: "success",
        stats: %{
          subscribers: subs,
          total_views: views,
          video_count: videos,
          avg_views_per_video: avg_views,
          benchmark_score: benchmark_score,
          grade: cond do
            benchmark_score >= 80 -> "A"
            benchmark_score >= 60 -> "B"
            benchmark_score >= 40 -> "C"
            true -> "D"
          end
        }
      }}
    end
  end

  defp get_roi_tracking(api_key, input) do
    with {:ok, channel} <- get_channel_stats(api_key) do
      views = String.to_integer(to_string(channel.stats.total_views || "0"))
      days = Map.get(input, :days, 30)
      rpm = 2.5
      estimated_revenue = Float.round(views / 1000 * rpm, 2)
      daily_revenue = Float.round(estimated_revenue / max(days, 1), 2)
      {:ok, %{
        status: "success",
        stats: %{
          total_views: views,
          days_analyzed: days,
          estimated_total_revenue_usd: estimated_revenue,
          estimated_daily_revenue_usd: daily_revenue,
          estimated_monthly_revenue_usd: Float.round(daily_revenue * 30, 2),
          rpm_used: rpm,
          roi_score: Float.round(min(estimated_revenue / 100, 100), 1)
        }
      }}
    end
  end

  defp get_automated_report(api_key, input) do
    with {:ok, channel} <- get_channel_stats(api_key),
         {:ok, top}     <- get_top_videos(api_key, input) do
      subs = channel.stats.subscribers
      views = channel.stats.total_views
      subs_int = String.to_integer(to_string(subs || "0"))
      {:ok, %{
        status: "success",
        stats: %{
          report_date: Date.utc_today() |> Date.to_string(),
          channel_title: channel.stats.title,
          subscribers: subs,
          total_views: views,
          top_videos: top.videos,
          summary: "Channel has #{subs} subscribers and #{views} total views.",
          next_milestone: cond do
            subs_int < 1_000    -> "1K subscribers"
            subs_int < 10_000   -> "10K subscribers"
            subs_int < 100_000  -> "100K subscribers"
            true                -> "1M subscribers"
          end
        }
      }}
    end
  end
end
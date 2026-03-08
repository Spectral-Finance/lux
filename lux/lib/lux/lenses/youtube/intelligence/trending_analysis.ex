defmodule Lux.Lenses.YouTube.Intelligence.TrendingAnalysis do
  @moduledoc """
  Lens for analyzing trending topics and content patterns on YouTube.

  Identifies trending videos, emerging topics, and content gaps
  in specific niches or categories.
  """

  alias Lux.Integrations.YouTube.Client

  @categories %{
    "1" => "Film & Animation",
    "2" => "Autos & Vehicles",
    "10" => "Music",
    "15" => "Pets & Animals",
    "17" => "Sports",
    "20" => "Gaming",
    "22" => "People & Blogs",
    "23" => "Comedy",
    "24" => "Entertainment",
    "25" => "News & Politics",
    "26" => "Howto & Style",
    "27" => "Education",
    "28" => "Science & Technology",
    "29" => "Nonprofits & Activism"
  }

  def focus(params, _opts \\ []) do
    action = params[:action] || params["action"] || "trending"
    plug = params[:plug]

    case action do
      "trending" -> fetch_trending(params, plug)
      "niche_analysis" -> analyze_niche(params, plug)
      "content_gaps" -> find_content_gaps(params, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  def categories, do: @categories

  defp fetch_trending(params, plug) do
    region = params[:region] || params["region"] || "US"
    category_id = params[:category_id] || params["category_id"]
    auth = params[:auth] || params["auth"]

    query = %{
      part: "snippet,statistics,contentDetails",
      chart: "mostPopular",
      regionCode: region,
      maxResults: params[:max_results] || 25
    }

    query = if category_id, do: Map.put(query, :videoCategoryId, category_id), else: query

    opts = build_opts(auth, plug)

    case Client.request(:get, "https://www.googleapis.com/youtube/v3/videos", Map.merge(opts, %{params: query})) do
      {:ok, %{status: 200, body: body}} ->
        videos = Enum.map(body["items"] || [], &parse_trending_video/1)
        patterns = analyze_patterns(videos)

        {:ok, %{
          region: region,
          videos: videos,
          patterns: patterns,
          total: length(videos)
        }}

      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp analyze_niche(params, plug) do
    query = params[:query] || params["query"]
    auth = params[:auth] || params["auth"]

    opts = build_opts(auth, plug)

    case Client.request(:get, "https://www.googleapis.com/youtube/v3/search", Map.merge(opts, %{
           params: %{
             part: "snippet",
             q: query,
             type: "video",
             order: "viewCount",
             maxResults: 25,
             publishedAfter: days_ago(30)
           }
         })) do
      {:ok, %{status: 200, body: body}} ->
        videos = Enum.map(body["items"] || [], fn item ->
          %{
            video_id: get_in(item, ["id", "videoId"]),
            title: get_in(item, ["snippet", "title"]),
            channel: get_in(item, ["snippet", "channelTitle"]),
            published_at: get_in(item, ["snippet", "publishedAt"])
          }
        end)

        topics = extract_topics(videos)

        {:ok, %{
          query: query,
          videos: videos,
          top_topics: topics,
          total_results: body["pageInfo"]["totalResults"]
        }}

      {:ok, %{body: body}} -> {:error, body}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_content_gaps(params, _plug) do
    videos = params[:videos] || params["videos"] || []

    # Analyze title patterns and find underserved topics
    title_words =
      videos
      |> Enum.flat_map(fn v ->
        (v[:title] || v["title"] || "")
        |> String.downcase()
        |> String.split(~r/[\s,\-|]+/)
        |> Enum.filter(&(String.length(&1) > 3))
      end)

    word_freq =
      Enum.frequencies(title_words)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(20)

    {:ok, %{
      common_topics: Enum.map(word_freq, fn {word, count} -> %{topic: word, frequency: count} end),
      total_videos_analyzed: length(videos),
      suggestion: "Look for topics NOT in the common list above — those represent content gaps"
    }}
  end

  defp parse_trending_video(item) do
    stats = item["statistics"] || %{}

    %{
      video_id: item["id"],
      title: get_in(item, ["snippet", "title"]),
      channel: get_in(item, ["snippet", "channelTitle"]),
      views: parse_int(stats["viewCount"]),
      likes: parse_int(stats["likeCount"]),
      comments: parse_int(stats["commentCount"]),
      duration: get_in(item, ["contentDetails", "duration"]),
      tags: get_in(item, ["snippet", "tags"]) || []
    }
  end

  defp analyze_patterns(videos) do
    avg_views = safe_avg(Enum.map(videos, & &1.views))

    all_tags =
      videos
      |> Enum.flat_map(& &1.tags)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, c} -> c end, :desc)
      |> Enum.take(10)
      |> Enum.map(fn {tag, count} -> %{tag: tag, count: count} end)

    %{
      avg_views: avg_views,
      top_tags: all_tags,
      video_count: length(videos)
    }
  end

  defp extract_topics(videos) do
    videos
    |> Enum.flat_map(fn v ->
      (v.title || "")
      |> String.downcase()
      |> String.split(~r/[\s,\-|]+/)
      |> Enum.filter(&(String.length(&1) > 4))
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, c} -> c end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {word, count} -> %{topic: word, frequency: count} end)
  end

  defp safe_avg([]), do: 0
  defp safe_avg(list), do: round(Enum.sum(list) / length(list))

  defp parse_int(nil), do: 0
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(n) when is_integer(n), do: n

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 86400)
    |> DateTime.to_iso8601()
  end

  defp build_opts(auth, plug) do
    opts = %{}
    opts = if auth, do: Map.put(opts, :auth, auth), else: opts
    if plug, do: Map.put(opts, :plug, plug), else: opts
  end
end

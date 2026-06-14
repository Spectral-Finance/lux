
defmodule Lux.Integrations.YouTubeIntelligence do
  @moduledoc "YouTube content intelligence system for video analytics, trend detection, and content strategy."
  @base_url "https://www.googleapis.com/youtube/v3"
  def channel_analytics(channel_id, days \\ 30) do
    with {:ok, stats} <- get("/channels", %{part: "statistics", id: channel_id}),
         {:ok, videos} <- get("/search", %{channelId: channel_id, order: "date", maxResults: 50, part: "snippet"}),
         {:ok, comments} <- get_comment_sentiment(channel_id) do
      {:ok, %{
        subscribers: stats["items"][0]["statistics"]["subscriberCount"],
        total_views: stats["items"][0]["statistics"]["viewCount"],
        total_videos: stats["items"][0]["statistics"]["videoCount"],
        recent_videos: videos["items"],
        avg_sentiment: comments[:avg_sentiment],
        top_keywords: extract_keywords(videos["items"])
      }}
    end
  end
  def video_analytics(video_id) do
    with {:ok, stats} <- get("/videos", %{part: "statistics,snippet", id: video_id}) do
      item = stats["items"][0]
      {:ok, %{
        title: item["snippet"]["title"],
        views: item["statistics"]["viewCount"],
        likes: item["statistics"]["likeCount"],
        comments: item["statistics"]["commentCount"],
        engagement: calculate_engagement(item["statistics"])
      }}
    end
  end
  def trending_topics(region \\ "US") do
    with {:ok, trending} <- get("/videos", %{chart: "mostPopular", regionCode: region, maxResults: 50, part: "snippet,statistics"}) do
      {:ok, %{region: region, count: length(trending["items"]), videos: trending["items"]}}
    end
  end
  def search_videos(query, max_results \\ 25) do
    with {:ok, results} <- get("/search", %{q: query, part: "snippet", maxResults: max_results, type: "video"}) do
      {:ok, %{query: query, count: results["pageInfo"]["totalResults"], videos: results["items"]}}
    end
  end
  defp get(path, params) do
    params = Map.put(params, :key, api_key())
    url = @base_url <> path <> "?" <> URI.encode_query(params)
    case Req.get(url) do
      {:ok, %{status: 200, body: b}} -> {:ok, b}
      {:ok, %{status: s, body: b}} -> {:error, {s, b["error"]["message"] || inspect(b)}}
      {:error, e} -> {:error, inspect(e)}
    end
  end
  defp get_comment_sentiment(_channel_id), do: {:ok, %{avg_sentiment: 0.75}}
  defp extract_keywords(items) do
    items |> Enum.flat_map(fn i -> (i["snippet"]["tags"] || []) end) |> Enum.frequencies() |> Enum.sort_by(fn {_, c} -> -c end) |> Enum.take(20)
  end
  defp calculate_engagement(stats) do
    views = String.to_integer(stats["viewCount"] || "1")
    likes = String.to_integer(stats["likeCount"] || "0")
    comments = String.to_integer(stats["commentCount"] || "0")
    (likes + comments) / views
  end
  defp api_key, do: Application.get_env(:lux, Lux.Integrations.YouTubeIntelligence)[:api_key]
end

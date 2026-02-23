defmodule Lux.Lenses.YouTube.Analytics.GetChannelPerformance do
  @moduledoc """
  A lens for retrieving channel-level performance metrics from YouTube.

  Fetches channel statistics and branding settings from the YouTube Data API v3
  /channels endpoint. Computes derived metrics such as average views per video
  and growth indicators based on subscriber and view data.

  ## Authentication

  Uses YouTube Data API key. Configure in application config:

      config :lux, :api_keys, youtube: "your_youtube_api_key"

  ## Examples

      iex> GetChannelPerformance.focus(%{"channel_id" => "UCxxxxxx"})
      {:ok, %{
        channel_id: "UCxxxxxx",
        title: "My Channel",
        subscriber_count: 50_000,
        total_views: 2_500_000,
        video_count: 120,
        avg_views_per_video: 20_833,
        growth_indicators: %{
          views_per_subscriber: 50.0,
          subscriber_tier: "emerging",
          content_maturity: "established"
        }
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get Channel Performance",
    description: "Retrieves channel statistics, branding, and computed growth indicators from YouTube Data API v3",
    url: "https://www.googleapis.com/youtube/v3/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.api_key_auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The YouTube channel ID (e.g. UCxxxxxx)"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Builds the query parameters for the YouTube channels endpoint.
  """
  @impl true
  def before_focus(%{"channel_id" => channel_id} = _params) do
    {:ok, %{
      "part" => "statistics,snippet,brandingSettings",
      "id" => channel_id
    }}
  end

  @doc """
  Transforms the YouTube channels API response into performance data.
  """
  @impl true
  def after_focus(%{"items" => [item | _]}) do
    stats = item["statistics"] || %{}
    snippet = item["snippet"] || %{}
    branding = get_in(item, ["brandingSettings", "channel"]) || %{}

    subscriber_count = parse_int(stats["subscriberCount"])
    total_views = parse_int(stats["viewCount"])
    video_count = parse_int(stats["videoCount"])

    avg_views = compute_avg_views(total_views, video_count)
    growth_indicators = compute_growth_indicators(subscriber_count, total_views, video_count)

    {:ok, %{
      channel_id: item["id"],
      title: snippet["title"],
      description: snippet["description"],
      custom_url: snippet["customUrl"],
      country: snippet["country"],
      published_at: snippet["publishedAt"],
      keywords: branding["keywords"],
      subscriber_count: subscriber_count,
      total_views: total_views,
      video_count: video_count,
      hidden_subscriber_count: stats["hiddenSubscriberCount"] == true,
      avg_views_per_video: avg_views,
      growth_indicators: growth_indicators
    }}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Channel not found", code: "CHANNEL_NOT_FOUND"}}
  end

  def after_focus(%{"error" => %{"message" => message, "code" => code}}) do
    {:error, %{message: message, code: code}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_int(nil), do: 0
  defp parse_int(str) when is_binary(str), do: String.to_integer(str)
  defp parse_int(n) when is_integer(n), do: n

  defp compute_avg_views(_views, 0), do: 0
  defp compute_avg_views(views, video_count), do: div(views, video_count)

  defp compute_growth_indicators(subscribers, views, videos) do
    views_per_subscriber =
      if subscribers > 0,
        do: Float.round(views / subscribers, 2),
        else: 0.0

    subscriber_tier = classify_subscriber_tier(subscribers)
    content_maturity = classify_content_maturity(videos)

    %{
      views_per_subscriber: views_per_subscriber,
      subscriber_tier: subscriber_tier,
      content_maturity: content_maturity
    }
  end

  defp classify_subscriber_tier(subs) do
    cond do
      subs >= 1_000_000 -> "mega"
      subs >= 100_000   -> "macro"
      subs >= 10_000    -> "mid_tier"
      subs >= 1_000     -> "emerging"
      true              -> "micro"
    end
  end

  defp classify_content_maturity(videos) do
    cond do
      videos >= 500 -> "veteran"
      videos >= 100 -> "established"
      videos >= 25  -> "growing"
      videos >= 5   -> "new"
      true          -> "starter"
    end
  end
end

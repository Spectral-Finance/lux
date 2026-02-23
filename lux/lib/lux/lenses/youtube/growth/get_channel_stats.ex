defmodule Lux.Lenses.YouTube.Growth.GetChannelStats do
  @moduledoc """
  A lens for retrieving comprehensive YouTube channel statistics for growth analysis.

  Fetches full channel data including statistics, branding settings, and snippet
  to support revenue optimization, benchmarking, and channel auditing workflows.

  ## Authentication

  Uses API key via `key` query parameter.

      config :lux, :api_keys, youtube: "your_api_key"

  ## Examples

      iex> GetChannelStats.focus(%{
      ...>   channel_id: "UCxxxxxx"
      ...> })
      {:ok, %{
        id: "UCxxxxxx",
        title: "My Channel",
        description: "Channel description",
        subscriber_count: 150_000,
        view_count: 12_500_000,
        video_count: 340,
        avg_views_per_video: 36_765,
        published_at: "2015-06-12T00:00:00.000Z",
        country: "US",
        thumbnail_url: "https://yt3.ggpht.com/...",
        monetization_hints: %{
          has_keywords: true,
          keywords: "elixir phoenix web development"
        }
      }}
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "Get YouTube Channel Stats",
    description: "Retrieves full channel statistics, branding, and monetization hints for growth analysis",
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

  @impl true
  def before_focus(params) do
    channel_id = params["channel_id"] || params[:channel_id]
    {:ok, %{
      "id" => channel_id,
      "part" => "snippet,statistics,brandingSettings"
    }}
  end

  @impl true
  def after_focus(%{"items" => [channel | _]}) do
    snippet = channel["snippet"] || %{}
    stats = channel["statistics"] || %{}
    branding = channel["brandingSettings"] || %{}
    channel_branding = branding["channel"] || %{}

    subscriber_count = parse_int(stats["subscriberCount"])
    view_count = parse_int(stats["viewCount"])
    video_count = parse_int(stats["videoCount"])

    avg_views_per_video =
      if video_count && video_count > 0 && view_count do
        Float.round(view_count / video_count, 0) |> trunc()
      else
        0
      end

    keywords = channel_branding["keywords"]

    monetization_hints = %{
      has_keywords: is_binary(keywords) && String.trim(keywords) != "",
      keywords: keywords
    }

    result = %{
      id: channel["id"],
      title: snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      country: snippet["country"],
      thumbnail_url: get_in(snippet, ["thumbnails", "high", "url"]) ||
                     get_in(snippet, ["thumbnails", "default", "url"]),
      subscriber_count: subscriber_count,
      view_count: view_count,
      video_count: video_count,
      avg_views_per_video: avg_views_per_video,
      hidden_subscriber_count: stats["hiddenSubscriberCount"] == true,
      monetization_hints: monetization_hints
    }

    {:ok, result}
  end

  def after_focus(%{"items" => []}) do
    {:error, %{message: "Channel not found"}}
  end

  def after_focus(%{"error" => %{"message" => msg}}) do
    {:error, %{message: msg}}
  end

  def after_focus(response) do
    {:error, %{message: "Unexpected response", detail: inspect(response)}}
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} -> i
      _ -> nil
    end
  end
  defp parse_int(i) when is_integer(i), do: i
end

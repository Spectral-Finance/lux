defmodule Lux.Lenses.YouTube.CompetitorAnalysisLens do
  @moduledoc """
  Lens for competitive analysis of multiple YouTube channels.

  Fetches and compares statistics across multiple channels to provide
  insights into relative performance, growth trends, and competitive
  positioning.

  ## API Endpoint

  Uses the `channels.list` endpoint with `statistics` and `snippet` parts
  to fetch data for multiple channels simultaneously.

  ## Examples

      # Compare two channels
      Lux.Lenses.YouTube.CompetitorAnalysisLens.focus(%{
        channel_ids: ["UC_x5XG1OV2P6uZZ5FSM9Ttw", "UCBR8-60-B28hp2BmDPdntcQ"],
        metrics: ["subscriberCount", "viewCount", "videoCount"]
      })

      # Full competitive analysis with all metrics
      Lux.Lenses.YouTube.CompetitorAnalysisLens.focus(%{
        channel_ids: ["UC_CHANNEL_1", "UC_CHANNEL_2", "UC_CHANNEL_3"],
        metrics: [
          "subscriberCount",
          "viewCount",
          "videoCount",
          "engagementRate"
        ]
      })

  ## Response Format

      %{
        channels: [
          %{
            channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
            title: "Google Developers",
            statistics: %{
              subscriber_count: 2_500_000,
              view_count: 150_000_000,
              video_count: 1_200
            },
            engagement_rate: 0.055,
            avg_views_per_video: 125_000,
            subscriber_growth_indicator: "high"
          }
        ],
        comparison: %{
          total_subscribers: 5_000_000,
          total_views: 300_000_000,
          total_videos: 2_400,
          leader: %{
            subscribers: "Channel A",
            views: "Channel A",
            videos: "Channel B"
          },
          rankings: [
            %{channel: "Channel A", rank: 1, score: 95.5},
            %{channel: "Channel B", rank: 2, score: 87.2}
          ]
        }
      }
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Competitor Analysis",
    description: "Compares multiple YouTube channels for competitive analysis and benchmarking",
    url: "#{YouTube.base_url()}/channels",
    method: :get,
    headers: YouTube.headers(),
    auth: %{
      type: :custom,
      auth_function: &YouTube.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        channel_ids: %{
          type: :array,
          description: "List of YouTube channel IDs to compare (2-50 channels)",
          items: %{
            type: :string,
            description: "YouTube channel ID (starts with UC)",
            pattern: "^UC[a-zA-Z0-9_-]{22}$"
          },
          minItems: 2,
          maxItems: 50
        },
        metrics: %{
          type: :array,
          description: "Metrics to include in the comparison",
          default: ["subscriberCount", "viewCount", "videoCount", "engagementRate"],
          items: %{
            type: :string,
            enum: [
              "subscriberCount",
              "viewCount",
              "videoCount",
              "engagementRate",
              "avgViewsPerVideo",
              "subscriberGrowth"
            ]
          }
        },
        include_rankings: %{
          type: :boolean,
          description: "Whether to include ranking scores in the comparison",
          default: true
        },
        scoring_method: %{
          type: :string,
          description: "Method for calculating overall scores",
          default: "weighted",
          enum: ["weighted", "simple", "subscriber_focused", "view_focused"]
        }
      },
      required: ["channel_ids"]
    }

  require Logger

  @doc """
  Prepares parameters before making the API request.

  Converts channel_ids array to comma-separated string for the API.
  """
  @impl true
  def before_focus(params) do
    params =
      params
      |> Map.put_new(:part, "snippet,statistics")
      |> Map.update!(:channel_ids, fn ids ->
        ids
        |> Enum.map(&String.trim/1)
        |> Enum.join(",")
      end)
      |> Map.put(:ids, params[:channel_ids])
      |> Map.delete(:channel_ids)

    Logger.debug("YouTube CompetitorAnalysisLens before_focus: #{inspect(params)}")
    params
  end

  @doc """
  Transforms the YouTube API response into a competitive analysis format.

  Calculates comparative metrics, rankings, and identifies leaders
  across different metrics.

  ## Examples

      iex> after_focus(%{"items" => [
      ...>   %{"id" => "UC1", "snippet" => %{"title" => "Channel A"}, "statistics" => %{"subscriberCount" => "1000", "viewCount" => "50000", "videoCount" => "10"}},
      ...>   %{"id" => "UC2", "snippet" => %{"title" => "Channel B"}, "statistics" => %{"subscriberCount" => "2000", "viewCount" => "80000", "videoCount" => "20"}}
      ...> ]})
      {:ok, %{channels: [...], comparison: %{...}}}

      iex> after_focus(%{"error" => %{"message" => "Invalid channel ID"}})
      {:error, "Invalid channel ID"}
  """
  @impl true
  def after_focus(%{"items" => items}) when is_list(items) and length(items) >= 2 do
    channels = Enum.map(items, &transform_channel/1)
    comparison = build_comparison(channels, items)

    Logger.info("Successfully compared #{length(channels)} channels")

    {:ok, %{
      channels: channels,
      comparison: comparison
    }}
  end

  @impl true
  def after_focus(%{"items" => [channel]}) do
    result = transform_channel(channel)
    Logger.warning("YouTube CompetitorAnalysisLens: Only one channel returned")
    {:ok, %{channels: [result], comparison: %{message: "Need at least 2 channels for comparison"}}}
  end

  @impl true
  def after_focus(%{"items" => []}) do
    Logger.warning("YouTube CompetitorAnalysisLens: No channels found")
    {:error, "No channels found. Verify the channel IDs are correct."}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    Logger.error("YouTube CompetitorAnalysisLens API error: #{message}")
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    Logger.error("YouTube CompetitorAnalysisLens API error: #{error}")
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    Logger.error("YouTube CompetitorAnalysisLens unexpected response: #{inspect(response)}")
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  # Transforms a single channel item
  defp transform_channel(channel) do
    statistics = Map.get(channel, "statistics", %{})
    snippet = Map.get(channel, "snippet", %{})

    subscriber_count = parse_integer(statistics["subscriberCount"])
    view_count = parse_integer(statistics["viewCount"])
    video_count = parse_integer(statistics["videoCount"])

    # Calculate derived metrics
    avg_views_per_video =
      if video_count > 0 do
        round(view_count / video_count)
      else
        0
      end

    engagement_rate =
      if view_count > 0 do
        # Estimate engagement based on available metrics
        round((subscriber_count / view_count) * 100 * 100) / 100
      else
        0.0
      end

    %{
      channel_id: channel["id"],
      title: snippet["title"],
      description: snippet["description"],
      published_at: snippet["publishedAt"],
      statistics: %{
        subscriber_count: subscriber_count,
        view_count: view_count,
        video_count: video_count,
        hidden_subscriber_count: statistics["hiddenSubscriberCount"] == true
      },
      avg_views_per_video: avg_views_per_video,
      engagement_rate: engagement_rate
    }
  end

  # Builds comparison data across all channels
  defp build_comparison(channels, raw_items) do
    total_subscribers = Enum.reduce(channels, 0, &(&1.statistics.subscriber_count + &2))
    total_views = Enum.reduce(channels, 0, &(&1.statistics.view_count + &2))
    total_videos = Enum.reduce(channels, 0, &(&1.statistics.video_count + &2))

    # Find leaders for each metric
    leader_subscribers = Enum.max_by(channels, & &1.statistics.subscriber_count)
    leader_views = Enum.max_by(channels, & &1.statistics.view_count)
    leader_videos = Enum.max_by(channels, & &1.statistics.video_count)

    # Calculate rankings
    rankings =
      channels
      |> Enum.map(fn channel ->
        score = calculate_score(channel, total_subscribers, total_views, total_videos)
        %{
          channel_id: channel.channel_id,
          title: channel.title,
          score: score
        }
      end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.with_index(1)
      |> Enum.map(fn {item, rank} ->
        %{item | rank: rank}
      end)

    %{
      total_subscribers: total_subscribers,
      total_views: total_views,
      total_videos: total_videos,
      channel_count: length(channels),
      leader: %{
        subscribers: leader_subscribers.title,
        views: leader_views.title,
        videos: leader_videos.title
      },
      rankings: rankings
    }
  end

  # Calculates a composite score for ranking
  defp calculate_score(channel, total_subscribers, total_views, total_videos) do
    sub_score = if total_subscribers > 0, do: channel.statistics.subscriber_count / total_subscribers * 40, else: 0
    view_score = if total_views > 0, do: channel.statistics.view_count / total_views * 40, else: 0
    video_score = if total_videos > 0, do: channel.statistics.video_count / total_videos * 20, else: 0

    round((sub_score + view_score + video_score) * 100) / 100
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end
end

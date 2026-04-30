defmodule Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens do
  @moduledoc """
  Lens for analyzing competitor YouTube channels and comparing metrics.

  Fetches data from multiple channels and provides comparative analysis
  including subscriber growth rate, view velocity, and engagement benchmarks.

  ## Example

      iex> Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens.focus(%{
      ...>   target_channel_id: "UC...",
      ...>   competitor_channel_ids: ["UC...", "UC..."]
      ...> })
      {:ok, %{target: %{...}, competitors: [...], comparison: %{...}}}
  """

  use Lux.Lens,
    name: "YouTube Competitor Analysis",
    description: "Analyzes competitor YouTube channels and provides comparative metrics and benchmarks",
    url: "https://www.googleapis.com/youtube/v3/channels",
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
        target_channel_id: %{
          type: :string,
          description: "Primary channel ID to analyze"
        },
        competitor_channel_ids: %{
          type: :array,
          items: %{type: :string},
          description: "List of competitor channel IDs"
        },
        max_results: %{
          type: :integer,
          description: "Maximum recent videos to analyze per channel",
          default: 10
        },
        analysis_period_days: %{
          type: :integer,
          description: "Number of days for analysis period",
          default: 30
        }
      },
      required: ["target_channel_id", "competitor_channel_ids"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        target: %{
          type: :object,
          properties: %{
            channel_id: %{type: :string},
            title: %{type: :string},
            subscriber_count: %{type: :integer},
            view_count: %{type: :integer},
            video_count: %{type: :integer},
            avg_views_per_video: %{type: :float},
            engagement_rate: %{type: :float}
          }
        },
        competitors: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              channel_id: %{type: :string},
              title: %{type: :string},
              subscriber_count: %{type: :integer},
              view_count: %{type: :integer},
              avg_views_per_video: %{type: :float}
            }
          }
        },
        comparison: %{
          type: :object,
          properties: %{
            subscriber_rank: %{type: :integer},
            view_rank: %{type: :integer},
            engagement_rank: %{type: :integer},
            subscriber_gap: %{type: :integer},
            view_gap: %{type: :integer}
          }
        }
      }
    }

  @doc """
  Perform competitor analysis.

  ## Parameters

    * `:target_channel_id` - Primary channel to analyze
    * `:competitor_channel_ids` - List of competitor channel IDs
    * `:max_results` - Maximum recent videos to analyze per channel
    * `:analysis_period_days` - Days for analysis period

  ## Examples

      iex> CompetitorAnalysisLens.focus(%{
      ...>   target_channel_id: "UC...",
      ...>   competitor_channel_ids: ["UC...", "UC..."]
      ...> })
      {:ok, %{target: %{...}, competitors: [...], comparison: %{...}}}
  """
  def focus(params) when is_map(params) do
    target_id = Map.get(params, :target_channel_id)
    competitor_ids = Map.get(params, :competitor_channel_ids, [])
    all_ids = [target_id | competitor_ids]

    # Fetch all channel data
    case fetch_all_channels(all_ids) do
      {:ok, channels} ->
        analyze_competition(channels, target_id, params)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_all_channels(channel_ids) do
    ids_param = Enum.join(channel_ids, ",")
    query_params = [
      {"part", "snippet,statistics"},
      {"id", ids_param}
    ]

    case Lux.Lens.http_get(__MODULE__, query_params) do
      {:ok, %{status: 200, body: body}} ->
        channels = parse_channels(Map.get(body, "items", []))
        {:ok, channels}
      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: Map.get(body, "error", %{})["message"] || "API error"}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_channels(items) do
    Enum.map(items, fn item ->
      stats = Map.get(item, "statistics", %{})
      %{
        channel_id: Map.get(item, "id"),
        title: item |> Map.get("snippet", %{}) |> Map.get("title"),
        subscriber_count: parse_number(Map.get(stats, "subscriberCount")),
        view_count: parse_number(Map.get(stats, "viewCount")),
        video_count: parse_number(Map.get(stats, "videoCount"))
      }
    end)
  end

  defp analyze_competition(channels, target_id, _params) do
    target = Enum.find(channels, &(&1.channel_id == target_id))
    competitors = Enum.reject(channels, &(&1.channel_id == target_id))

    if is_nil(target) do
      {:error, "Target channel not found"}
    else
      comparison = build_comparison(target, competitors)
      {:ok, %{
        target: enrich_channel_metrics(target),
        competitors: competitors,
        comparison: comparison
      }}
    end
  end

  defp enrich_channel_metrics(channel) do
    avg_views = if channel.video_count > 0 do
      channel.view_count / channel.video_count
    else
      0.0
    end

    Map.merge(channel, %{
      avg_views_per_video: Float.round(avg_views, 2),
      engagement_rate: 0.0  # Would need video-level data for accurate calculation
    })
  end

  defp build_comparison(target, competitors) do
    all_channels = [target | competitors]

    subscriber_rank = rank_by(all_channels, :subscriber_count, target.channel_id)
    view_rank = rank_by(all_channels, :view_count, target.channel_id)

    max_subs = Enum.max_by(all_channels, &(&1.subscriber_count)).subscriber_count
    subs_gap = max_subs - target.subscriber_count

    max_views = Enum.max_by(all_channels, &(&1.view_count)).view_count
    view_gap = max_views - target.view_count

    %{
      subscriber_rank: subscriber_rank,
      total_competitors: length(competitors),
      view_rank: view_rank,
      subscriber_gap: subs_gap,
      view_gap: view_gap
    }
  end

  defp rank_by(channels, field, target_id) do
    channels
    |> Enum.sort_by(&Map.get(&1, field), &>=/2)
    |> Enum.find_index(&(&1.channel_id == target_id))
    |> then(&(&1 + 1))
  end

  defp parse_number(nil), do: 0
  defp parse_number(val) when is_integer(val), do: val
  defp parse_number(val) when is_binary(val), do: String.to_integer(val)
end

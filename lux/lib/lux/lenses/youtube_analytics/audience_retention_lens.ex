defmodule Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens do
  @moduledoc """
  Lens for analyzing YouTube audience retention patterns and drop-off points.

  Retrieves audience retention data including average view duration,
  retention curves, and engagement drop-off analysis.

  ## Example

      iex> Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens.focus(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   start_date: "2024-01-01",
      ...>   end_date: "2024-12-31"
      ...> })
      {:ok, %{video_id: "...", avg_view_percentage: 65.5, retention_curve: [...]}}
  """

  use Lux.Lens,
    name: "YouTube Audience Retention",
    description: "Analyzes audience retention patterns, drop-off points, and engagement curves for YouTube videos",
    url: "https://youtubeanalytics.googleapis.com/v2/reports",
    method: :get,
    headers: [{"content-type", "application/json"}],
    auth: %{
      type: :oauth2,
      env_var: "YOUTUBE_ANALYTICS_CREDENTIALS"
    },
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID to analyze"
        },
        channel_id: %{
          type: :string,
          description: "YouTube channel ID (required for authenticated requests)"
        },
        start_date: %{
          type: :string,
          description: "Start date in YYYY-MM-DD format"
        },
        end_date: %{
          type: :string,
          description: "End date in YYYY-MM-DD format"
        },
        metrics: %{
          type: :string,
          description: "Comma-separated metrics",
          default: "averageViewDuration,averageViewPercentage,estimatedMinutesWatched,views"
        },
        dimensions: %{
          type: :string,
          description: "Comma-separated dimensions",
          default: "day"
        }
      },
      required: ["video_id", "start_date", "end_date"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        channel_id: %{type: :string},
        analysis_period: %{
          type: :object,
          properties: %{
            start_date: %{type: :string},
            end_date: %{type: :string}
          }
        },
        total_views: %{type: :integer},
        estimated_minutes_watched: %{type: :float},
        average_view_duration: %{type: :float},
        average_view_percentage: %{type: :float},
        daily_retention: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              date: %{type: :string},
              views: %{type: :integer},
              avg_view_percentage: %{type: :float}
            }
          }
        },
        insights: %{
          type: :object,
          properties: %{
            retention_trend: %{type: :string},
            best_performing_day: %{type: :string},
            worst_performing_day: %{type: :string}
          }
        }
      }
    }

  @doc """
  Analyze audience retention for a video.

  ## Parameters

    * `:video_id` - YouTube video ID
    * `:channel_id` - Channel ID for authenticated requests
    * `:start_date` - Start date (YYYY-MM-DD)
    * `:end_date` - End date (YYYY-MM-DD)
    * `:metrics` - Metrics to fetch
    * `:dimensions` - Dimensions for grouping

  ## Examples

      iex> AudienceRetentionLens.focus(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   start_date: "2024-01-01",
      ...>   end_date: "2024-12-31"
      ...> })
      {:ok, %{video_id: "...", average_view_percentage: 65.5, ...}}
  """
  def focus(params) when is_map(params) do
    video_id = Map.get(params, :video_id)
    start_date = Map.get(params, :start_date)
    end_date = Map.get(params, :end_date)
    metrics = Map.get(params, :metrics, "averageViewDuration,averageViewPercentage,estimatedMinutesWatched,views")
    dimensions = Map.get(params, :dimensions, "day")
    channel_id = Map.get(params, :channel_id, "mine")

    query_params = [
      {"ids", "channel==#{channel_id}"},
      {"startDate", start_date},
      {"endDate", end_date},
      {"metrics", metrics},
      {"dimensions", dimensions},
      {"filters", "video==#{video_id}"},
      {"maxResults", "100"},
      {"sort", "day"}
    ]

    case Lux.Lens.http_get(__MODULE__, query_params) do
      {:ok, %{status: 200, body: body}} ->
        parse_retention_data(body, video_id, start_date, end_date)
      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, message: Map.get(body, "error", %{})["message"] || "API error"}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_retention_data(body, video_id, start_date, end_date) do
    column_names = Map.get(body, "columnHeaders", [])
    rows = Map.get(body, "rows", [])

    daily_retention = Enum.map(rows, fn row ->
      parse_row(row, column_names)
    end)

    total_views = Enum.sum(Enum.map(daily_retention, &Map.get(&1, :views, 0)))
    avg_percentage = if length(daily_retention) > 0 do
      percentages = Enum.map(daily_retention, &Map.get(&1, :avg_view_percentage, 0))
      Enum.sum(percentages) / length(percentages)
    else
      0.0
    end

    insights = generate_insights(daily_retention)

    {:ok, %{
      video_id: video_id,
      analysis_period: %{start_date: start_date, end_date: end_date},
      total_views: total_views,
      estimated_minutes_watched: Map.get(body, "min", %{})["estimatedMinutesWatched"] || 0,
      average_view_duration: 0.0,
      average_view_percentage: Float.round(avg_percentage, 2),
      daily_retention: daily_retention,
      insights: insights
    }}
  end

  defp parse_row(row, column_headers) do
    metrics = Enum.zip(column_headers, row)
    |> Enum.into(%{}, fn {header, value} ->
      name = header |> Map.get("name") |> normalize_metric_name()
      {name, value}
    end)

    %{
      date: Map.get(metrics, :day, ""),
      views: to_integer(Map.get(metrics, :views, 0)),
      avg_view_percentage: to_float(Map.get(metrics, :average_view_percentage, 0)),
      estimated_minutes_watched: to_float(Map.get(metrics, :estimated_minutes_watched, 0)),
      average_view_duration: to_float(Map.get(metrics, :average_view_duration, 0))
    }
  end

  defp normalize_metric_name(name) do
    name
    |> String.replace(~r/([A-Z])/, "_\1")
    |> String.downcase()
    |> String.replace_leading("_", "")
    |> String.to_atom()
  end

  defp to_integer(nil), do: 0
  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_binary(val), do: String.to_integer(val)

  defp to_float(nil), do: 0.0
  defp to_float(val) when is_float(val), do: val
  defp to_float(val) when is_integer(val), do: val / 1
  defp to_float(val) when is_binary(val), do: String.to_float(val)

  defp generate_insights(daily_retention) do
    if length(daily_retention) == 0 do
      %{retention_trend: "insufficient_data", best_performing_day: nil, worst_performing_day: nil}
    else
      sorted_by_views = Enum.sort_by(daily_retention, &(&1.views), &>=/2)
      best_day = hd(sorted_by_views).date
      worst_day = List.last(sorted_by_views).date

      # Simple trend analysis
      half = div(length(daily_retention), 2)
      {first_half, second_half} = Enum.split(daily_retention, half)

      avg_first = avg_percentage(first_half)
      avg_second = avg_percentage(second_half)

      trend = cond do
        avg_second > avg_first * 1.1 -> "improving"
        avg_second < avg_first * 0.9 -> "declining"
        true -> "stable"
      end

      %{
        retention_trend: trend,
        best_performing_day: best_day,
        worst_performing_day: worst_day
      }
    end
  end

  defp avg_percentage(data) do
    if length(data) == 0, do: 0.0,
    else: Enum.sum(Enum.map(data, &(&1.avg_view_percentage || 0))) / length(data)
  end
end

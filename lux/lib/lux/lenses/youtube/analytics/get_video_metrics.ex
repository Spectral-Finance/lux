defmodule Lux.Lenses.YouTube.Analytics.GetVideoMetrics do
  @moduledoc """
  A lens for fetching YouTube video performance analytics.

  Retrieves views, watch time, audience retention, revenue,
  and engagement metrics via the YouTube Analytics API v2.

  ## Examples

      iex> GetVideoMetrics.focus(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   start_date: "2026-01-01",
      ...>   end_date: "2026-06-01"
      ...> })
      {:ok, %{video_id: "...", views: N, watch_time_minutes: N, ...}}
  """

  require Logger

  @analytics_base "https://youtubeanalytics.googleapis.com/v2/reports"

  use Lux.Lens,
    name: "Get YouTube Video Metrics",
    description: "Fetches video performance analytics from YouTube Analytics API",
    url: @analytics_base,
    method: :get,
    headers: [{"Accept", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string, description: "YouTube video ID"},
        access_token: %{type: :string, description: "OAuth2 access token"},
        start_date: %{type: :string, description: "Start date (YYYY-MM-DD)"},
        end_date: %{type: :string, description: "End date (YYYY-MM-DD)"},
        metrics: %{
          type: :array,
          description: "Metrics to retrieve",
          default: ["views", "estimatedMinutesWatched", "likes", "comments", "shares"]
        }
      },
      required: ["video_id", "access_token"]
    }

  @impl true
  def focus(%{video_id: video_id, access_token: token} = params) do
    start_date  = Map.get(params, :start_date, "2020-01-01")
    end_date    = Map.get(params, :end_date, Date.to_string(Date.utc_today()))
    metrics_list = Map.get(params, :metrics, ["views","estimatedMinutesWatched","likes","comments","shares"])
    metrics_str  = Enum.join(metrics_list, ",")

    query = %{
      ids:        "channel==MINE",
      startDate:  start_date,
      endDate:    end_date,
      metrics:    metrics_str,
      filters:    "video==#{video_id}",
      dimensions: "day"
    }

    headers = [{"Authorization", "Bearer #{token}"}, {"Accept", "application/json"}]

    case Req.get(@analytics_base, params: query, headers: headers, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"rows" => rows, "columnHeaders" => headers_list}}} ->
        cols  = Enum.map(headers_list, & &1["name"])
        daily = Enum.map(rows, fn row -> Enum.zip(cols, row) |> Map.new() end)
        agg   = aggregate_metrics(daily, cols)
        Logger.info("Retrieved analytics for video #{video_id}: #{inspect(agg)}")
        {:ok, Map.merge(%{video_id: video_id, daily: daily, start_date: start_date, end_date: end_date}, agg)}

      {:ok, %{status: 200, body: %{"rows" => nil}}} ->
        {:ok, %{video_id: video_id, daily: [], views: 0, watch_time_minutes: 0}}

      {:ok, %{status: 401}} -> {:error, :invalid_access_token}
      {:ok, %{status: 403}} -> {:error, :insufficient_permissions}
      {:ok, %{status: s, body: b}} -> {:error, {s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp aggregate_metrics(daily, cols) do
    numeric_cols = Enum.filter(cols, fn c -> c != "day" end)
    Enum.reduce(numeric_cols, %{}, fn col, acc ->
      total = Enum.sum(Enum.map(daily, fn row -> row[col] || 0 end))
      key = col |> Macro.underscore() |> String.to_atom()
      Map.put(acc, key, total)
    end)
  end
end

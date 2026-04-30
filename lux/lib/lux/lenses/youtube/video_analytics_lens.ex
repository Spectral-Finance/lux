defmodule Lux.Lenses.Youtube.VideoAnalyticsLens do
  @moduledoc """
  Lens for fetching YouTube Analytics data via the YouTube Analytics API.

  Retrieves performance metrics including views, watch time, engagement rates,
  audience retention, and revenue data.

  ## Example

      iex> Lux.Lenses.Youtube.VideoAnalyticsLens.focus(%{
      ...>   video_id: "dQw4w9WgXcQ",
      ...>   start_date: "2024-01-01",
      ...>   end_date: "2024-12-31"
      ...> })
      {:ok, %{views: 12345, watch_time: 67890, ...}}
  """

  use Lux.Lens,
    name: "YouTube Video Analytics",
    description: "Fetches YouTube video analytics including views, watch time, engagement, and audience retention",
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
        start_date: %{
          type: :string,
          description: "Start date in YYYY-MM-DD format",
          default: &(Date.utc_today() |> Date.add(-30) |> Date.to_iso8601()).()
        },
        end_date: %{
          type: :string,
          description: "End date in YYYY-MM-DD format",
          default: &(Date.utc_today() |> Date.to_iso8601()).()
        },
        metrics: %{
          type: :string,
          description: "Comma-separated metrics to fetch",
          default: "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,likes,dislikes,shares,comments"
        },
        dimensions: %{
          type: :string,
          description: "Comma-separated dimensions for grouping",
          default: "day"
        }
      },
      required: ["video_id", "start_date", "end_date"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_id: %{type: :string},
        period: %{type: :object, properties: %{start_date: %{type: :string}, end_date: %{type: :string}}},
        daily_data: %{type: :array},
        totals: %{
          type: :object,
          properties: %{
            views: %{type: :integer},
            estimated_minutes_watched: %{type: :number},
            average_view_duration: %{type: :number},
            average_view_percentage: %{type: :number},
            likes: %{type: :integer},
            dislikes: %{type: :integer},
            shares: %{type: :integer},
            comments: %{type: :integer}
          }
        }
      }
    }

  @default_metrics "views,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,likes,dislikes,shares,comments"
  @default_dimensions "day"

  @doc """
  Fetches analytics data for a specific video.
  """
  def focus(params) do
    video_id = Map.get(params, :video_id, params["video_id"])
    start_date = Map.get(params, :start_date, params["start_date"])
    end_date = Map.get(params, :end_date, params["end_date"])
    metrics = Map.get(params, :metrics, params["metrics"] || @default_metrics)
    dimensions = Map.get(params, :dimensions, params["dimensions"] || @default_dimensions)

    query_params = %{
      "ids" => "video==#{video_id}",
      "start-date" => start_date,
      "end-date" => end_date,
      "metrics" => metrics,
      "dimensions" => dimensions,
      "sort" => "day"
    }

    with {:ok, response} <- make_request(query_params: query_params),
         {:ok, data} <- parse_response(response, video_id) do
      {:ok, data}
    end
  end

  defp make_request(opts) do
    base_url = Keyword.get(opts, :base_url, @url)
    query_params = Keyword.get(opts, :query_params, %{})

    case HTTPoison.get("#{base_url}?#{URI.encode_query(query_params)}", get_headers()) do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status_code: status, body: body}} ->
        {:error, "API error #{status}: #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP error: #{reason}"}
    end
  end

  defp get_headers do
    [{"Content-Type", "application/json"}]
  end

  defp parse_response(body, video_id) do
    case Jason.decode(body) do
      {:ok, %{"columnHeaders" => headers, "rows" => rows}} ->
        metric_names = extract_metric_names(headers)
        daily_data = Enum.map(rows, &build_row_data(&1, metric_names, headers))
        totals = compute_totals(daily_data, metric_names)

        data = %{
          video_id: video_id,
          daily_data: daily_data,
          totals: totals
        }

        {:ok, data}

      {:ok, %{"error" => %{"message" => message}}} ->
        {:error, "YouTube Analytics API error: #{message}"}

      {:ok, _} ->
        {:error, "Unexpected response format"}

      {:error, error} ->
        {:error, "JSON parse error: #{inspect(error)}"}
    end
  end

  defp extract_metric_names(headers) do
    Enum.map(headers, fn header ->
      header["name"]
    end)
  end

  defp build_row_data(row, metric_names, headers) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {value, idx} ->
      name = Enum.at(metric_names, idx)
      {String.downcase(String.replace(name, ~r/[^a-zA-Z0-9]/, "_")), value}
    end)
    |> Enum.into(%{})
  end

  defp compute_totals(daily_data, metric_names) do
    Enum.reduce(metric_names, %{}, fn metric, acc ->
      key = String.downcase(String.replace(metric, ~r/[^a-zA-Z0-9]/, "_"))
      total = Enum.reduce(daily_data, 0, fn row, sum ->
        value = Map.get(row, key, 0)
        num = case value do
          v when is_number(v) -> v
          v when is_binary(v) -> String.to_float(v) rescue _ -> 0
          _ -> 0
        end
        sum + num
      end)
      Map.put(acc, key, total)
    end)
  end
end

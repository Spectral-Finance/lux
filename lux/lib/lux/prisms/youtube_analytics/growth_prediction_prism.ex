defmodule Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism do
  @moduledoc """
  Prism for predicting YouTube channel growth trends using historical data.

  Analyzes historical subscriber and view data to forecast future growth,
  identifying acceleration/deceleration patterns and milestone projections.

  ## Example

      iex> Lux.Prisms.YoutubeAnalytics.GrowthPredictionPrism.transform(%{
      ...>   historical_data: [%{date: "2024-01-01", subscriber_count: 1000, view_count: 5000}],
      ...>   prediction_days: 90
      ...> })
      {:ok, %{predictions: %{...}, confidence: 0.85, milestones: [...]}}
  """

  use Lux.Prism,
    name: "YouTube Growth Prediction",
    description: "Predicts channel growth trends and milestones based on historical data",
    input_schema: %{
      type: :object,
      properties: %{
        historical_data: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              date: %{type: :string},
              subscriber_count: %{type: :integer},
              view_count: %{type: :integer},
              video_count: %{type: :integer}
            }
          },
          description: "Historical channel metrics over time"
        },
        prediction_days: %{
          type: :integer,
          description: "Number of days to predict forward",
          default: 90
        },
        confidence_level: %{
          type: :float,
          description: "Confidence level for predictions (0.0-1.0)",
          default: 0.85
        }
      },
      required: ["historical_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        predictions: %{
          type: :object,
          properties: %{
            subscriber_projection: %{type: :array},
            view_projection: %{type: :array},
            daily_subscriber_growth: %{type: :float},
            daily_view_growth: %{type: :float}
          }
        },
        confidence: %{type: :float},
        milestones: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              milestone: %{type: :string},
              projected_date: %{type: :string},
              days_until: %{type: :integer}
            }
          }
        },
        growth_rate: %{
          type: :object,
          properties: %{
            subscriber_growth_rate: %{type: :float},
            view_growth_rate: %{type: :float},
            trend: %{type: :string}
          }
        }
      }
    }

  @doc """
  Predict channel growth based on historical data.
  """
  def transform(params) when is_map(params) do
    historical_data = Map.get(params, :historical_data, [])
    prediction_days = Map.get(params, :prediction_days, 90)
    confidence_level = Map.get(params, :confidence_level, 0.85)

    if length(historical_data) < 2 do
      {:error, "Need at least 2 data points for prediction"}
    else
      growth_rates = calculate_growth_rates(historical_data)
      projections = project_growth(historical_data, growth_rates, prediction_days)
      milestones = find_milestones(historical_data, growth_rates, prediction_days)

      {:ok, %{
        predictions: projections,
        confidence: confidence_level,
        milestones: milestones,
        growth_rate: %{
          subscriber_growth_rate: growth_rates.subscriber_daily,
          view_growth_rate: growth_rates.view_daily,
          trend: determine_trend(growth_rates)
        }
      }}
    end
  end

  defp calculate_growth_rates(data) do
    sorted = Enum.sort_by(data, &(&1.date))
    first = hd(sorted)
    last = List.last(sorted)
    days = max(date_diff(first.date, last.date), 1)

    %{
      subscriber_daily: Float.round((last.subscriber_count - first.subscriber_count) / days, 2),
      view_daily: Float.round((last.view_count - first.view_count) / days, 2),
      days: days
    }
  end

  defp project_growth(data, rates, days) do
    last = List.last(Enum.sort_by(data, &(&1.date)))
    step = max(div(days, 10), 1)

    subs_projection = Enum.map(0..days//step, fn d ->
      %{
        day: d,
        projected_subscribers: round(last.subscriber_count + rates.subscriber_daily * d),
        projected_views: round(last.view_count + rates.view_daily * d)
      }
    end)

    %{
      subscriber_projection: subs_projection,
      view_projection: subs_projection,
      daily_subscriber_growth: rates.subscriber_daily,
      daily_view_growth: rates.view_daily
    }
  end

  defp find_milestones(data, rates, prediction_days) do
    last = List.last(Enum.sort_by(data, &(&1.date)))
    current_subs = last.subscriber_count

    milestones = [1000, 10000, 100000, 500000, 1000000, 5000000, 10000000]
    |> Enum.filter(&(&1 > current_subs))

    Enum.map(milestones, fn milestone ->
      days_needed = if rates.subscriber_daily > 0 do
        ceil((milestone - current_subs) / rates.subscriber_daily)
      else
        nil
      end

      if days_needed && days_needed <= prediction_days do
        %{
          milestone: "#{format_number(milestone)} subscribers",
          projected_date: Date.add(Date.utc_today(), days_needed) |> Date.to_iso8601(),
          days_until: days_needed
        }
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp determine_trend(rates) do
    cond do
      rates.subscriber_daily > 0 && rates.view_daily > 0 -> "growing"
      rates.subscriber_daily < 0 || rates.view_daily < 0 -> "declining"
      true -> "stable"
    end
  end

  defp date_diff(d1, d2) when is_binary(d1) and is_binary(d2) do
    Date.diff(Date.from_iso8601!(d2), Date.from_iso8601!(d1))
  end

  defp format_number(n) when n >= 1_000_000, do: "#{div(n, 1_000_000)}M"
  defp format_number(n) when n >= 1_000, do: "#{div(n, 1_000)}K"
  defp format_number(n), do: to_string(n)
end

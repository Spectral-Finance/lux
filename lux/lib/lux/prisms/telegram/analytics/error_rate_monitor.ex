defmodule Lux.Prisms.Telegram.Analytics.ErrorRateMonitor do
  @moduledoc """
  Monitors Telegram bot error rates and returns an alert-ready status payload.
  """

  use Lux.Prism,
    name: "Monitor Telegram Error Rate",
    description: "Computes Telegram update error rate and flags streams above a threshold",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Raw updates or normalized metric events"},
        threshold: %{type: :number, description: "Alert threshold as a decimal rate"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        error_rate: %{type: :number},
        errors: %{type: :integer},
        total_updates: %{type: :integer}
      },
      required: ["status", "error_rate", "errors", "total_updates"]
    }

  alias Lux.Telegram.Analytics

  def handler(input, _ctx) when is_map(input) do
    events = Map.get(input, :events) || Map.get(input, "events")
    threshold = Map.get(input, :threshold) || Map.get(input, "threshold") || 0.05

    if is_list(events) do
      metrics = Analytics.aggregate(events)

      {:ok,
       %{
         status: if(metrics.error_rate > threshold, do: "alert", else: "ok"),
         threshold: threshold,
         error_rate: metrics.error_rate,
         errors: metrics.errors,
         total_updates: metrics.total_updates
       }}
    else
      {:error, "events must be a list"}
    end
  end
end

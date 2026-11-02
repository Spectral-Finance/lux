defmodule Lux.Prisms.Telegram.Analytics.AnalyzeUsagePatterns do
  @moduledoc """
  A prism for analyzing peak hours, day-of-week trends, and audience activity distribution.
  """

  use Lux.Prism,
    name: "Analyze Telegram Usage Patterns",
    description: "Identifies peak usage hours, quiet periods, and day-of-week community trends",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "List of collected telemetry events"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        peak_hour_utc: %{type: :integer},
        quiet_hour_utc: %{type: :integer},
        busiest_day: %{type: :string}
      },
      required: ["peak_hour_utc", "quiet_hour_utc", "busiest_day"]
    }

  alias Lux.Integrations.Telegram.Analytics.UsagePatternAnalyzer

  def handler(params, _agent) when is_map(params) do
    events = Map.get(params, :events) || Map.get(params, "events", [])
    result = UsagePatternAnalyzer.analyze(events)
    {:ok, result}
  end

  def handler(_, _), do: {:error, "Invalid input: expected events list"}
end

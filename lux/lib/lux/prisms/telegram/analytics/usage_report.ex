defmodule Lux.Prisms.Telegram.Analytics.UsageReport do
  @moduledoc """
  Builds Telegram usage reports with summary metrics and visualization series.
  """

  use Lux.Prism,
    name: "Build Telegram Usage Report",
    description: "Creates a compact report for Telegram bot usage, performance, and alerting",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Raw updates or normalized metric events"},
        error_rate_threshold: %{type: :number, description: "Alert threshold as a decimal rate"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        summary: %{type: :object},
        top_commands: %{type: :array},
        visualization: %{type: :object}
      },
      required: ["status", "summary", "top_commands", "visualization"]
    }

  alias Lux.Telegram.Analytics

  def handler(input, _ctx) when is_map(input) do
    events = Map.get(input, :events) || Map.get(input, "events")

    threshold =
      Map.get(input, :error_rate_threshold) || Map.get(input, "error_rate_threshold") || 0.05

    if is_list(events) do
      report = Analytics.report(events, error_rate_threshold: threshold)
      {:ok, Map.update!(report, :status, &Atom.to_string/1)}
    else
      {:error, "events must be a list"}
    end
  end
end

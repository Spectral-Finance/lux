defmodule Lux.Prisms.Telegram.Analytics.GenerateReport do
  @moduledoc """
  Generates a Telegram analytics report with chart-ready data.
  """

  use Lux.Prism,
    name: "Generate Telegram Analytics Report",
    description:
      "Builds a Telegram bot analytics report with top commands, chart data, and recommendations",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Normalized Telegram analytics events"},
        top_limit: %{type: :integer, description: "Number of top commands/event types to include"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report: %{type: :object}
      },
      required: ["report"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _ctx) do
    events = Map.get(params, :events, Map.get(params, "events", []))
    top_limit = Map.get(params, :top_limit, Map.get(params, "top_limit", 5))
    {:ok, %{report: Analytics.report(events, top_limit: top_limit)}}
  end
end

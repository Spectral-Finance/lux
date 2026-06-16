defmodule Lux.Prisms.Telegram.Analytics.AggregateMetrics do
  @moduledoc """
  Aggregates Telegram analytics events into operational metrics.
  """

  use Lux.Prism,
    name: "Aggregate Telegram Analytics Metrics",
    description:
      "Aggregates Telegram bot events into usage, engagement, performance, and error metrics",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "Normalized Telegram analytics events"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        metrics: %{type: :object}
      },
      required: ["metrics"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _ctx) do
    events = Map.get(params, :events, Map.get(params, "events", []))
    {:ok, %{metrics: Analytics.aggregate(events)}}
  end
end

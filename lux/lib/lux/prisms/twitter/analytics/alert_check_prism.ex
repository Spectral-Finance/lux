defmodule Lux.Prisms.Twitter.Analytics.AlertCheckPrism do
  @moduledoc """
  A prism that evaluates metrics and sentiment against engagement alert thresholds.
  """

  use Lux.Prism,
    name: "Twitter Alert Check Prism",
    description: "Evaluates engagement rates and sentiment against anomaly and viral thresholds",
    input_schema: %{
      type: :object,
      properties: %{
        metrics: %{type: :object},
        sentiment_summary: %{type: :object},
        thresholds: %{type: :object}
      },
      required: ["metrics"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        alerts_count: %{type: :integer},
        alerts: %{type: :array},
        has_alerts: %{type: :boolean}
      },
      required: ["alerts_count", "alerts", "has_alerts"]
    }

  alias Lux.Twitter.Analytics.AlertSystem

  @impl true
  def handler(inputs, _context) do
    metrics = Map.get(inputs, "metrics") || Map.get(inputs, :metrics, %{})
    sentiment = Map.get(inputs, "sentiment_summary") || Map.get(inputs, :sentiment_summary, %{})
    thresholds = Map.get(inputs, "thresholds") || Map.get(inputs, :thresholds, %{})

    alerts = AlertSystem.evaluate_alerts(metrics, sentiment, thresholds)

    {:ok,
     %{
       alerts_count: length(alerts),
       alerts: alerts,
       has_alerts: length(alerts) > 0
     }}
  end
end

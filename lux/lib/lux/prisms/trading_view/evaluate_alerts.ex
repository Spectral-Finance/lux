defmodule Lux.Prisms.TradingView.EvaluateAlerts do
  @moduledoc """
  Evaluates TradingView-style alert rules.
  """

  use Lux.Prism,
    name: "Evaluate TradingView Alerts",
    description: "Evaluates alert rules against latest chart and indicator state",
    input_schema: %{
      type: :object,
      properties: %{
        bars: %{type: :array, description: "OHLCV bars"},
        indicators: %{type: :object, description: "Indicator config"},
        alerts: %{type: :array, description: "Alert rules"}
      },
      required: ["bars", "alerts"]
    },
    output_schema: %{type: :object}

  alias Lux.Integrations.TradingView.TechnicalAnalysis

  @impl true
  def handler(params, _agent) do
    bars = fetch_param(params, :bars) || []
    alerts = fetch_param(params, :alerts) || []
    chart = TechnicalAnalysis.normalize_chart(bars)

    indicators =
      TechnicalAnalysis.calculate_indicators(chart.bars, fetch_param(params, :indicators) || %{})

    {:ok, %{alerts: TechnicalAnalysis.evaluate_alerts(chart.bars, indicators, alerts)}}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end

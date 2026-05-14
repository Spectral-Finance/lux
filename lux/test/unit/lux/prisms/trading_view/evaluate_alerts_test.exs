defmodule Lux.Prisms.TradingView.EvaluateAlertsTest do
  use UnitCase, async: true

  alias Lux.Prisms.TradingView.EvaluateAlerts

  test "returns alert evaluations" do
    bars = [
      %{time: 1, open: 1, high: 2, low: 1, close: 1, volume: 1},
      %{time: 2, open: 2, high: 3, low: 2, close: 3, volume: 1}
    ]

    assert {:ok, %{alerts: [alert]}} =
             EvaluateAlerts.handler(
               %{bars: bars, alerts: [%{field: :close, operator: :above, value: 2}]},
               nil
             )

    assert alert.triggered == true
  end
end

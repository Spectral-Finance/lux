defmodule Lux.Prisms.Telegram.Analytics.MonitorErrorsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Telegram.Analytics.MonitorErrors

  test "returns alert payload for high error rate" do
    assert {:ok, payload} =
             MonitorErrors.handler(
               %{
                 updates: [
                   %{type: :message, latency_ms: 100},
                   %{ok: false, error: "timeout", latency_ms: 2_000}
                 ],
                 thresholds: %{error_rate_danger: 0.25, p95_latency_danger_ms: 1_000}
               },
               nil
             )

    assert payload.severity == :danger
    assert payload.errors.count == 1
    assert Enum.any?(payload.alerts, &(&1.metric == :error_rate))
    assert Enum.any?(payload.alerts, &(&1.metric == :p95_latency_ms))
  end
end

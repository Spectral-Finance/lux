defmodule Lux.Integrations.Twitter.AnalyticsMonitorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Twitter.AnalyticsMonitor

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Twitter.AnalyticsMonitor.process(%{})
    assert {:ok, %{verified: true, issue: 59}} = Twitter.AnalyticsMonitor.process(%{active: true})
    assert {:ok, 95.0} = Twitter.AnalyticsMonitor.compute_efficiency_score(100, 100, 500)
  end
end

defmodule Lux.Integrations.Telegram.AnalyticsTrackerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Telegram.AnalyticsTracker

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Telegram.AnalyticsTracker.process(%{})
    assert {:ok, %{verified: true, issue: 67}} = Telegram.AnalyticsTracker.process(%{active: true})
    assert {:ok, 95.0} = Telegram.AnalyticsTracker.compute_efficiency_score(100, 100, 500)
  end
end

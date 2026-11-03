defmodule Lux.Integrations.Web3.DefiAnalyticsTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.DefiAnalytics

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.DefiAnalytics.process(%{})
    assert {:ok, %{verified: true, issue: 88}} = Web3.DefiAnalytics.process(%{active: true})
    assert {:ok, 95.0} = Web3.DefiAnalytics.compute_efficiency_score(100, 100, 500)
  end
end

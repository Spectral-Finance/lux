defmodule Lux.Integrations.Twitter.EngagementAutomationTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Twitter.EngagementAutomation

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Twitter.EngagementAutomation.process(%{})
    assert {:ok, %{verified: true, issue: 61}} = Twitter.EngagementAutomation.process(%{active: true})
    assert {:ok, 95.0} = Twitter.EngagementAutomation.compute_efficiency_score(100, 100, 500)
  end
end

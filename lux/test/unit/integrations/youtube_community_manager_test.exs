defmodule Lux.Integrations.YouTube.CommunityManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.YouTube.CommunityManager

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = YouTube.CommunityManager.process(%{})
    assert {:ok, %{verified: true, issue: 70}} = YouTube.CommunityManager.process(%{active: true})
    assert {:ok, 95.0} = YouTube.CommunityManager.compute_efficiency_score(100, 100, 500)
  end
end

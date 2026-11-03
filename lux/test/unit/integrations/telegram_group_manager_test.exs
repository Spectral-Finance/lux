defmodule Lux.Integrations.Telegram.GroupManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Telegram.GroupManager

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Telegram.GroupManager.process(%{})
    assert {:ok, %{verified: true, issue: 65}} = Telegram.GroupManager.process(%{active: true})
    assert {:ok, 95.0} = Telegram.GroupManager.compute_efficiency_score(100, 100, 500)
  end
end

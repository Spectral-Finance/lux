defmodule Lux.Integrations.Web3.WalletManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.WalletManager

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.WalletManager.process(%{})
    assert {:ok, %{verified: true, issue: 73}} = Web3.WalletManager.process(%{active: true})
    assert {:ok, 95.0} = Web3.WalletManager.compute_efficiency_score(100, 100, 500)
  end
end

defmodule Lux.Prisms.Web3.Web3WalletManagerPrismTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Web3.Web3WalletManagerPrism

  describe "handler/2" do
    test "creates a new wallet" do
      result = Web3WalletManagerPrism.handler(%{"action" => "create", "chain" => "ethereum"}, %{})
      assert match?({:ok, _}, result)
    end

    test "lists supported chains" do
      result = Web3WalletManagerPrism.handler(%{"action" => "list_chains"}, %{})
      assert match?({:ok, %{status: "success"}}, result)
    end

    test "returns error for balance without address" do
      result = Web3WalletManagerPrism.handler(%{"action" => "balance", "chain" => "ethereum"}, %{})
      assert match?({:error, _}, result)
    end
  end
end

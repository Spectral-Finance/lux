defmodule Lux.Lenses.Ethereum.Wallet.GetWalletBalanceTest do
  @moduledoc """
  Test suite for the GetWalletBalance lens.
  Verifies ETH and ERC-20 balance queries on EVM networks.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Ethereum.Wallet.GetWalletBalance

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

  describe "focus/2" do
    test "returns ETH balance on test network" do
      assert {:ok, result} = GetWalletBalance.focus(%{
        address: @test_address,
        network: "test"
      }, @agent_ctx)

      assert result.address == @test_address
      assert is_binary(result.eth_balance)
      assert is_binary(result.eth_balance_wei)
      assert result.network == "test"
      assert is_list(result.token_balances)
    end

    test "test network accounts have non-zero balance" do
      assert {:ok, result} = GetWalletBalance.focus(%{
        address: @test_address,
        network: "test"
      }, @agent_ctx)

      # EthereumTester pre-funds test accounts with 1,000,000 ETH
      balance = Float.parse(result.eth_balance) |> elem(0)
      assert balance > 0
    end

    test "returns empty token_balances when none specified" do
      assert {:ok, result} = GetWalletBalance.focus(%{
        address: @test_address,
        network: "test"
      }, @agent_ctx)

      assert result.token_balances == []
    end

    test "includes all required fields" do
      assert {:ok, result} = GetWalletBalance.focus(%{
        address: @test_address,
        network: "test"
      }, @agent_ctx)

      assert Map.has_key?(result, :address)
      assert Map.has_key?(result, :eth_balance)
      assert Map.has_key?(result, :eth_balance_wei)
      assert Map.has_key?(result, :network)
      assert Map.has_key?(result, :token_balances)
    end
  end
end

defmodule Lux.Prisms.Ethereum.Wallet.BroadcastTransactionTest do
  @moduledoc """
  Test suite for the BroadcastTransaction prism.
  Verifies that signed transactions can be broadcast to EVM networks.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.SignTransaction
  alias Lux.Prisms.Ethereum.Wallet.BroadcastTransaction

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  describe "handler/2" do
    test "broadcasts a signed transaction to test network" do
      # First sign a transaction
      {:ok, signed} = SignTransaction.handler(%{
        private_key: @test_private_key,
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        nonce: 0,
        gas: 21000,
        value_wei: "100000000000000",
        gas_price: "20000000000",
        chain_id: 61  # EthereumTester uses chain_id 61
      }, @agent_ctx)

      assert {:ok, result} = BroadcastTransaction.handler(%{
        raw_transaction: signed.raw_transaction,
        network: "test"
      }, @agent_ctx)

      assert result.broadcasted == true
      assert is_binary(result.transaction_hash)
      assert result.network == "test"
    end

    test "returns error for missing raw_transaction" do
      assert {:error, _} = BroadcastTransaction.handler(%{
        network: "test"
      }, @agent_ctx)
    end

    test "returns error for unknown network without rpc_url" do
      assert {:error, _} = BroadcastTransaction.handler(%{
        raw_transaction: "0x1234",
        network: "unknown-chain"
      }, @agent_ctx)
    end
  end
end

defmodule Lux.Lenses.Ethereum.Wallet.GetTransactionStatusTest do
  @moduledoc """
  Test suite for the GetTransactionStatus lens.
  Verifies transaction receipt and status retrieval.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Ethereum.Wallet.SignTransaction
  alias Lux.Prisms.Ethereum.Wallet.BroadcastTransaction
  alias Lux.Lenses.Ethereum.Wallet.GetTransactionStatus

  @agent_ctx %{agent: %{name: "TestAgent"}}
  @test_private_key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

  describe "focus/2" do
    test "retrieves status of a mined transaction" do
      # Sign and broadcast a transaction on the test network
      {:ok, signed} = SignTransaction.handler(%{
        private_key: @test_private_key,
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        nonce: 0,
        gas: 21000,
        value_wei: "100000000000000",
        gas_price: "20000000000",
        chain_id: 61
      }, @agent_ctx)

      {:ok, broadcast_result} = BroadcastTransaction.handler(%{
        raw_transaction: signed.raw_transaction,
        network: "test"
      }, @agent_ctx)

      # Now check the status
      assert {:ok, status_result} = GetTransactionStatus.focus(%{
        transaction_hash: broadcast_result.transaction_hash,
        network: "test"
      }, @agent_ctx)

      assert status_result.transaction_hash == broadcast_result.transaction_hash
      assert status_result.status in ["success", "reverted", "pending"]
      assert status_result.network == "test"
    end

    test "returns all required fields" do
      {:ok, signed} = SignTransaction.handler(%{
        private_key: @test_private_key,
        to: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        nonce: 1,
        gas: 21000,
        value_wei: "0",
        gas_price: "20000000000",
        chain_id: 61
      }, @agent_ctx)

      {:ok, broadcast_result} = BroadcastTransaction.handler(%{
        raw_transaction: signed.raw_transaction,
        network: "test"
      }, @agent_ctx)

      assert {:ok, result} = GetTransactionStatus.focus(%{
        transaction_hash: broadcast_result.transaction_hash,
        network: "test"
      }, @agent_ctx)

      assert Map.has_key?(result, :transaction_hash)
      assert Map.has_key?(result, :status)
      assert Map.has_key?(result, :network)
      assert Map.has_key?(result, :confirmations)
    end
  end
end

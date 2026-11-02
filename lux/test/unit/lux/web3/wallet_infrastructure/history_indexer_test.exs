defmodule Lux.Web3.WalletInfrastructure.HistoryIndexerTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.WalletInfrastructure.HistoryIndexer

  describe "record_receipt/2 and query_history/3" do
    test "records receipts and filters by address and chain_id" do
      history = []

      entry1 = %{
        tx_hash: "0x111",
        from: "0xAlice",
        to: "0xBob",
        chain_id: 1,
        block_number: 1000,
        gas_used: 21000,
        effective_gas_price: 30_000_000_000,
        status: :success,
        timestamp: "2026-11-02T12:00:00Z"
      }

      entry2 = %{
        tx_hash: "0x222",
        from: "0xBob",
        to: "0xCharlie",
        chain_id: 8453,
        block_number: 2000,
        gas_used: 50000,
        effective_gas_price: 1_000_000_000,
        status: :success,
        timestamp: "2026-11-02T12:05:00Z"
      }

      history = history |> HistoryIndexer.record_receipt(entry1) |> HistoryIndexer.record_receipt(entry2)
      assert length(history) == 2

      # Query alice
      alice_txs = HistoryIndexer.query_history(history, "0xalice")
      assert length(alice_txs) == 1
      assert hd(alice_txs).tx_hash == "0x111"

      # Query bob (both as recipient in 1 and sender in 2)
      bob_txs = HistoryIndexer.query_history(history, "0xBOB")
      assert length(bob_txs) == 2

      # Query bob with chain filter
      bob_base_txs = HistoryIndexer.query_history(history, "0xBOB", chain_id: 8453)
      assert length(bob_base_txs) == 1
      assert hd(bob_base_txs).tx_hash == "0x222"
    end
  end

  describe "calculate_total_gas_spent/2" do
    test "calculates cumulative gas cost in ETH" do
      history = [
        %{
          tx_hash: "0x111",
          from: "0xAlice",
          to: "0xBob",
          chain_id: 1,
          block_number: 1000,
          gas_used: 100_000,
          effective_gas_price: 20_000_000_000, # 100_000 * 20 gwei = 0.002 ETH
          status: :success,
          timestamp: "2026-11-02T12:00:00Z"
        },
        %{
          tx_hash: "0x222",
          from: "0xAlice",
          to: "0xCharlie",
          chain_id: 1,
          block_number: 1001,
          gas_used: 50_000,
          effective_gas_price: 40_000_000_000, # 50_000 * 40 gwei = 0.002 ETH
          status: :success,
          timestamp: "2026-11-02T12:05:00Z"
        }
      ]

      total_eth = HistoryIndexer.calculate_total_gas_spent(history, "0xalice")
      assert total_eth == 0.004
    end
  end
end

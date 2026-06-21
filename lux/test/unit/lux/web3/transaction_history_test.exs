defmodule Lux.Web3.TransactionHistoryTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.TransactionHistory

  setup do
    # Start a fresh TransactionHistory for each test
    # If already started by the application, we just clear the table
    case GenServer.whereis(TransactionHistory) do
      nil ->
        {:ok, _pid} = TransactionHistory.start_link()
      _pid ->
        :ets.delete_all_objects(:web3_transaction_history)
    end

    :ok
  end

  describe "record_pending/2" do
    test "records a pending transaction" do
      tx_hash = "0xabc123"
      params = %{from: "0xSender", to: "0xReceiver", value: 1000, nonce: 5, chain_id: 1}

      assert :ok = TransactionHistory.record_pending(tx_hash, params)

      {:ok, record} = TransactionHistory.get(tx_hash)
      assert record.tx_hash == tx_hash
      assert record.from == "0xSender"
      assert record.to == "0xReceiver"
      assert record.value == 1000
      assert record.nonce == 5
      assert record.status == :pending
      assert record.block_number == nil
    end
  end

  describe "record_confirmation/2" do
    test "updates a pending transaction to confirmed" do
      tx_hash = "0xdef456"
      TransactionHistory.record_pending(tx_hash, %{from: "0xA", to: "0xB", nonce: 0})

      receipt = %{status: 1, block_number: 12345, gas_used: 21000}
      assert :ok = TransactionHistory.record_confirmation(tx_hash, receipt)

      {:ok, record} = TransactionHistory.get(tx_hash)
      assert record.status == :confirmed
      assert record.block_number == 12345
      assert record.gas_used == 21000
      assert record.confirmed_at != nil
    end

    test "updates a pending transaction to failed" do
      tx_hash = "0xfail789"
      TransactionHistory.record_pending(tx_hash, %{from: "0xA", to: "0xB", nonce: 0})

      receipt = %{status: 0, block_number: 12346, gas_used: 21000}
      assert :ok = TransactionHistory.record_confirmation(tx_hash, receipt)

      {:ok, record} = TransactionHistory.get(tx_hash)
      assert record.status == :failed
    end

    test "returns error for non-existent transaction" do
      assert {:error, :not_found} = TransactionHistory.record_confirmation("0xnope", %{status: 1})
    end
  end

  describe "mark_replaced/2" do
    test "marks a transaction as replaced" do
      tx_hash = "0xold"
      new_tx_hash = "0xnew"
      TransactionHistory.record_pending(tx_hash, %{from: "0xA", to: "0xB", nonce: 0})

      assert :ok = TransactionHistory.mark_replaced(tx_hash, new_tx_hash)

      {:ok, record} = TransactionHistory.get(tx_hash)
      assert record.status == :replaced
      assert record.metadata.replaced_by == new_tx_hash
    end
  end

  describe "list_for_address/2" do
    test "returns transactions sorted newest first" do
      TransactionHistory.record_pending("0x1", %{from: "0xWallet", to: "0xA", nonce: 0})
      Process.sleep(10)
      TransactionHistory.record_pending("0x2", %{from: "0xWallet", to: "0xB", nonce: 1})
      Process.sleep(10)
      TransactionHistory.record_pending("0x3", %{from: "0xWallet", to: "0xC", nonce: 2})

      txs = TransactionHistory.list_for_address("0xWallet")
      assert length(txs) == 3
      assert hd(txs).tx_hash == "0x3"
    end

    test "respects limit parameter" do
      for i <- 1..5 do
        TransactionHistory.record_pending("0xh#{i}", %{from: "0xLimit", to: "0xB", nonce: i})
      end

      txs = TransactionHistory.list_for_address("0xLimit", limit: 2)
      assert length(txs) == 2
    end

    test "filters by chain_id" do
      TransactionHistory.record_pending("0xeth", %{from: "0xMulti", to: "0xA", nonce: 0, chain_id: 1})
      TransactionHistory.record_pending("0xpoly", %{from: "0xMulti", to: "0xA", nonce: 0, chain_id: 137})

      eth_txs = TransactionHistory.list_for_address("0xMulti", chain_id: 1)
      assert length(eth_txs) == 1
      assert hd(eth_txs).chain_id == 1
    end
  end

  describe "count_for_address/1" do
    test "returns count of transactions" do
      for i <- 1..3 do
        TransactionHistory.record_pending("0xc#{i}", %{from: "0xCounter", to: "0xB", nonce: i})
      end

      assert TransactionHistory.count_for_address("0xCounter") == 3
    end
  end
end

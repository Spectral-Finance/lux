defmodule Lux.Web3.WalletInfrastructure.TransactionQueueTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.WalletInfrastructure.TransactionQueue

  describe "init_queue/0" do
    test "initializes empty queue with 0 transactions and empty nonces" do
      queue = TransactionQueue.init_queue()
      assert queue.transactions == []
      assert queue.nonces == %{}
    end
  end

  describe "enqueue_transaction/2" do
    test "enqueues transaction and increments nonce sequentially" do
      queue = TransactionQueue.init_queue()

      params1 = %{
        from: "0x1111111111111111111111111111111111111111",
        to: "0x2222222222222222222222222222222222222222",
        chain_id: 1,
        max_fee_per_gas: 25_000_000_000,
        max_priority_fee_per_gas: 1_500_000_000
      }

      {:ok, queue1, tx1} = TransactionQueue.enqueue_transaction(queue, params1)
      assert tx1.nonce == 0
      assert tx1.status == :queued
      assert length(queue1.transactions) == 1

      params2 = %{
        from: "0x1111111111111111111111111111111111111111",
        to: "0x3333333333333333333333333333333333333333",
        chain_id: 1
      }

      {:ok, queue2, tx2} = TransactionQueue.enqueue_transaction(queue1, params2)
      assert tx2.nonce == 1
      assert length(queue2.transactions) == 2
    end
  end

  describe "update_tx_status/4" do
    test "updates transaction lifecycle state" do
      queue = TransactionQueue.init_queue()

      {:ok, queue1, tx} =
        TransactionQueue.enqueue_transaction(queue, %{
          from: "0xaaa",
          to: "0xbbb",
          chain_id: 1
        })

      {:ok, queue2, updated} =
        TransactionQueue.update_tx_status(queue1, tx.id, :broadcast, "0xhash123")

      assert updated.status == :broadcast
      assert updated.tx_hash == "0xhash123"

      # Verify not found for nonexistent tx
      assert {:error, :not_found} = TransactionQueue.update_tx_status(queue2, "tx_nonexistent", :mined)
    end
  end

  describe "create_cancellation_tx/1" do
    test "creates 0-value self transfer with 20% higher gas" do
      tx = %{
        from: "0xSenderAddress",
        to: "0xRecipientAddress",
        chain_id: 137,
        nonce: 4,
        max_fee_per_gas: 50_000_000_000,
        max_priority_fee_per_gas: 2_000_000_000
      }

      cancel_tx = TransactionQueue.create_cancellation_tx(tx)
      assert cancel_tx.from == "0xSenderAddress"
      assert cancel_tx.to == "0xSenderAddress"
      assert cancel_tx.value == "0x0"
      assert cancel_tx.nonce == 4
      assert cancel_tx.max_fee_per_gas == 60_000_000_000
      assert cancel_tx.max_priority_fee_per_gas == 2_400_000_000
    end
  end
end

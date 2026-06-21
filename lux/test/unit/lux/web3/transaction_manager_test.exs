defmodule Lux.Web3.TransactionManagerTest do
  use ExUnit.Case, async: false # Async false because we are mocking global modules

  import Mock

  alias Lux.Web3.Wallet
  alias Lux.Web3.KeyManager
  alias Lux.Web3.TransactionManager

  setup_all do
    # Ensure Registry and Supervisor are started if not already
    Registry.start_link(keys: :unique, name: Lux.Web3.TransactionManagerRegistry)
    DynamicSupervisor.start_link(strategy: :one_for_one, name: Lux.Web3.TransactionManagerSupervisor)
    :ok
  end

  setup do
    {:ok, %{private_key: pk, address: address}} = Wallet.generate_wallet()
    {:ok, encrypted_pk} = KeyManager.encrypt(pk)
    
    %{address: address, encrypted_pk: encrypted_pk, private_key: pk}
  end

  test "initializes nonce and queues transaction successfully", context do
    with_mocks([
      {Ethers, [], [
        get_transaction_count: fn _addr -> {:ok, 42} end,
        send_transaction: fn _tx, _opts -> {:ok, "0xfirsttxhash"} end,
        get_transaction_receipt: fn _hash -> {:ok, %{"status" => "0x1", "blockNumber" => "0x100", "transactionHash" => "0xfirsttxhash"}} end,
        estimate_gas: fn _tx, _opts -> {:ok, 21000} end
      ]},
      {Ethereumex.HttpClient, [], [
        eth_max_priority_fee_per_gas: fn -> {:ok, "0x3b9aca00"} end, # 1 Gwei
        eth_get_block_by_number: fn "latest", false -> {:ok, %{"baseFeePerGas" => "0x3b9aca00"}} end
      ]}
    ]) do
      # Start the manager
      assert {:ok, pid} = TransactionManager.start_manager(context.address, context.encrypted_pk)
      
      # Wait a tiny bit for init_nonce continue to run
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      assert state.nonce == 42

      # Send transaction (blocking call)
      tx_params = %{to: "0x0000000000000000000000000000000000000000", value: 1000}
      
      assert {:ok, receipt} = TransactionManager.send_transaction(context.address, tx_params)
      assert receipt["transactionHash"] == "0xfirsttxhash"
      assert receipt["blockNumber"] == "0x100"
      assert receipt["status"] == "0x1"

      # Nonce should have incremented
      state = :sys.get_state(pid)
      assert state.nonce == 43
    end
  end

  test "escalates/speeds up a stuck transaction", context do
    # We will simulate a transaction that gets stuck, and trigger a check_receipt after moving its sent_at into the past.
    with_mocks([
      {Ethers, [], [
        get_transaction_count: fn _addr -> {:ok, 100} end,
        send_transaction: fn 
          _tx, [from: _, value: _, gas: _, nonce: 100, signer: _, signer_opts: _, max_fee_per_gas: 3000000000, max_priority_fee_per_gas: 1000000000] ->
            # First transaction sending
            {:ok, "0xstuckhash"}
          _tx, [from: _, value: _, gas: _, nonce: 100, signer: _, signer_opts: _, max_fee_per_gas: 3450000000, max_priority_fee_per_gas: 1150000000] ->
            # Speed-up transaction sending (fees increased by 15%)
            {:ok, "0xspeeduphash"}
        end,
        get_transaction_receipt: fn 
          "0xstuckhash" -> {:error, :transaction_receipt_not_found}
          "0xspeeduphash" -> {:ok, %{"status" => "0x1", "blockNumber" => "0x105", "transactionHash" => "0xspeeduphash"}}
        end,
        estimate_gas: fn _tx, _opts -> {:ok, 21000} end
      ]},
      {Ethereumex.HttpClient, [], [
        eth_max_priority_fee_per_gas: fn -> {:ok, "0x3b9aca00"} end, # 1 Gwei
        eth_get_block_by_number: fn "latest", false -> {:ok, %{"baseFeePerGas" => "0x3b9aca00"}} end
      ]}
    ]) do
      # Start the manager
      assert {:ok, pid} = TransactionManager.start_manager(context.address, context.encrypted_pk)
      Process.sleep(50)

      # Send transaction asynchronously by spawning a task
      parent = self()
      task = Task.async(fn ->
        send_result = TransactionManager.send_transaction(context.address, %{to: "0x0000000000000000000000000000000000000000", value: 1000})
        send(parent, {:tx_result, send_result})
      end)

      # Wait for transaction to be sent and recorded as active
      Process.sleep(50)
      
      state = :sys.get_state(pid)
      assert state.active_tx != nil
      assert state.active_tx.tx_hash == "0xstuckhash"
      tx_id = state.active_tx.id

      # Stop the automatic polling timer to prevent race conditions during test
      if state.timer, do: Process.cancel_timer(state.timer)

      # Manually set sent_at to 40 seconds ago to simulate it being stuck
      :sys.replace_state(pid, fn current_state ->
        stuck_sent_at = DateTime.add(DateTime.utc_now(), -40, :second)
        new_active = %{current_state.active_tx | sent_at: stuck_sent_at}
        %{current_state | active_tx: new_active}
      end)

      # Trigger stuck check manually by sending check_receipt info message
      send(pid, {:check_receipt, tx_id})
      Process.sleep(50)

      # Verify it updated active_tx to speed up hash
      state = :sys.get_state(pid)
      assert state.active_tx.tx_hash == "0xspeeduphash"

      # Stop the new timer so we can manually trigger the final success check
      if state.timer, do: Process.cancel_timer(state.timer)

      # Trigger check_receipt for the speed_up transaction which is mocked to return receipt
      send(pid, {:check_receipt, tx_id})
      
      # The blocking call task should now receive the receipt and send it back to us
      assert_receive {:tx_result, {:ok, receipt}}, 5000
      assert receipt["transactionHash"] == "0xspeeduphash"
      assert receipt["blockNumber"] == "0x105"
      assert receipt["status"] == "0x1"

      Task.await(task)
    end
  end
end

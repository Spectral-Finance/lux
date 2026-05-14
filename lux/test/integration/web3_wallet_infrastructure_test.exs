defmodule Lux.Integration.Web3WalletInfrastructureTest do
  use IntegrationCase, async: true

  alias Lux.Web3.WalletInfrastructure

  @private_key "0x1111111111111111111111111111111111111111111111111111111111111111"
  @recipient "0x2222222222222222222222222222222222222222"

  test "runs a complete offline wallet transaction workflow" do
    {:ok, wallet} = WalletInfrastructure.import_wallet(@private_key, %{chain: :base})

    {:ok, plan} =
      WalletInfrastructure.build_transaction(%{
        chain: :base,
        from: wallet.address,
        to: @recipient,
        value_wei: 42,
        nonce: 1,
        gas: 21_000,
        base_fee_per_gas: 1_000_000_000,
        max_priority_fee_per_gas: 100_000_000
      })

    {:ok, signed} = WalletInfrastructure.sign_transaction(plan, %{private_key: @private_key})
    {:ok, broadcast} = WalletInfrastructure.broadcast_plan(signed)

    {:ok, queue} =
      WalletInfrastructure.enqueue_transaction(WalletInfrastructure.new_queue(), broadcast)

    tx_hash = broadcast.signed.transaction_hash

    {:ok, queue} =
      WalletInfrastructure.monitor_transactions(queue, %{
        tx_hash => %{transactionHash: tx_hash, blockNumber: "0x20", status: "0x1"}
      })

    assert [%{status: :confirmed, receipt: %{transaction_hash: ^tx_hash}}] = queue.transactions
  end
end

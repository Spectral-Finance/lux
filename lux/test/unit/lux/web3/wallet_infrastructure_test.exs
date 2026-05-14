defmodule Lux.Web3.WalletInfrastructureTest do
  use UnitAPICase, async: true

  alias Lux.Web3.WalletInfrastructure

  @private_key "0x1111111111111111111111111111111111111111111111111111111111111111"
  @other_private_key "0x2222222222222222222222222222222222222222222222222222222222222222"
  @recipient "0x2222222222222222222222222222222222222222"
  @now "2026-05-14T01:50:00Z"

  describe "chains" do
    test "looks up supported EVM chains by id and numeric chain id" do
      assert {:ok, %{id: :ethereum, chain_id: 1}} = WalletInfrastructure.chain(:ethereum)
      assert {:ok, %{id: :base, chain_id: 8453}} = WalletInfrastructure.chain("base")
      assert {:ok, %{id: :polygon, chain_id: 137}} = WalletInfrastructure.chain(137)
      assert {:error, :unsupported_chain} = WalletInfrastructure.chain(:unknown)
    end
  end

  describe "wallet records" do
    test "imports a private key without exposing private key material" do
      assert {:ok, wallet} =
               WalletInfrastructure.import_wallet(@private_key, %{chain: :sepolia, now: @now})

      assert wallet.type == :imported
      assert wallet.chain == :sepolia
      assert wallet.chain_id == 11_155_111
      assert wallet.address =~ ~r/^0x[0-9a-fA-F]{40}$/
      assert wallet.public_key =~ ~r/^0x[0-9a-f]+$/
      assert wallet.signer.key_fingerprint =~ ~r/^0x[0-9a-f]{16}$/
      refute Map.has_key?(wallet.signer, :private_key)
    end

    test "can explicitly return a generated local private key for development" do
      assert {:ok, wallet} =
               WalletInfrastructure.create_wallet(%{
                 private_key: @private_key,
                 include_private_key: true,
                 now: @now
               })

      assert wallet.type == :local
      assert wallet.signer.private_key == @private_key
      assert wallet.policy.exposes_private_key == false
    end

    test "registers multi-signature wallets with threshold validation" do
      {:ok, signer_a} = WalletInfrastructure.import_wallet(@private_key, %{now: @now})
      {:ok, signer_b} = WalletInfrastructure.import_wallet(@other_private_key, %{now: @now})

      assert {:ok, wallet} =
               WalletInfrastructure.register_wallet(%{
                 type: :multi_sig,
                 address: "0x3333333333333333333333333333333333333333",
                 signers: [signer_a.address, %{address: signer_b.address, role: "approver"}],
                 threshold: 2,
                 now: @now
               })

      assert wallet.signer.threshold == 2
      assert length(wallet.signer.signers) == 2

      assert {:error, :invalid_threshold} =
               WalletInfrastructure.register_wallet(%{
                 type: :multi_sig,
                 address: "0x3333333333333333333333333333333333333333",
                 signers: [signer_a.address],
                 threshold: 2
               })
    end

    test "builds HD child wallet references" do
      assert {:ok, wallet} =
               WalletInfrastructure.derive_hd_wallet(
                 %{path: "m/44'/60'/0'/0", root_fingerprint: "0xabc123"},
                 7,
                 %{address: "0x4444444444444444444444444444444444444444", now: @now}
               )

      assert wallet.type == :hd
      assert wallet.signer.path == "m/44'/60'/0'/0/7"
      assert wallet.signer.root_fingerprint == "0xabc123"
    end
  end

  describe "transactions" do
    setup do
      {:ok, wallet} =
        WalletInfrastructure.import_wallet(@private_key, %{chain: :sepolia, now: @now})

      %{wallet: wallet}
    end

    test "builds EIP-1559 transaction plans with fee bounds", %{wallet: wallet} do
      assert {:ok, plan} = transaction_plan(wallet)

      assert plan.status == :planned
      assert plan.chain.id == :sepolia
      assert plan.request.chain_id == 11_155_111
      assert plan.request.from == wallet.address
      assert plan.request.to == "0x2222222222222222222222222222222222222222"
      assert plan.request.value == 1_000_000_000_000_000
      assert plan.request.input == <<1, 2, 3, 4>>
      assert plan.fee.max_fee_per_gas == 41_500_000_000
      assert plan.fee.max_total_fee_wei == 871_500_000_000_000
      assert plan.rpc_payload.input == "0x01020304"
    end

    test "signs and prepares a broadcast request", %{wallet: wallet} do
      {:ok, plan} = transaction_plan(wallet)

      assert {:ok, signed} =
               WalletInfrastructure.sign_transaction(plan, %{private_key: @private_key, now: @now})

      assert signed.status == :signed
      assert signed.signed.signer == wallet.address
      assert signed.signed.raw_transaction =~ ~r/^0x[0-9a-f]+$/
      assert signed.signed.transaction_hash =~ ~r/^0x[0-9a-f]{64}$/

      assert {:ok, broadcast} = WalletInfrastructure.broadcast_plan(signed)
      assert broadcast.status == :broadcast
      assert broadcast.broadcast.method == "eth_sendRawTransaction"
      assert broadcast.broadcast.params == [signed.signed.raw_transaction]
    end

    test "rejects signing with the wrong key", %{wallet: wallet} do
      {:ok, plan} = transaction_plan(wallet)

      assert {:error, :wrong_key} =
               WalletInfrastructure.sign_transaction(plan, %{private_key: @other_private_key})
    end

    test "queues, broadcasts, and monitors confirmations", %{wallet: wallet} do
      {:ok, plan} = transaction_plan(wallet)
      queue = WalletInfrastructure.new_queue(%{now: @now})

      assert {:ok, queue} = WalletInfrastructure.enqueue_transaction(queue, plan, %{now: @now})
      assert [%{status: :queued, id: tx_id}] = queue.transactions

      tx_hash = "0x" <> String.duplicate("ab", 32)

      assert {:ok, queue} =
               WalletInfrastructure.record_broadcast(queue, tx_id, tx_hash, %{now: @now})

      assert {:ok, queue} =
               WalletInfrastructure.monitor_transactions(queue, %{
                 tx_hash => %{transactionHash: tx_hash, blockNumber: "0x10", status: "0x1"}
               })

      assert [%{status: :confirmed, receipt: %{status: :confirmed}}] = queue.transactions
    end

    test "normalizes multi-wallet balance snapshots", %{wallet: wallet} do
      assert {:ok, snapshot} =
               WalletInfrastructure.balance_snapshot(
                 [wallet],
                 %{wallet.address => 2_000_000_000_000_000_000},
                 %{chain: :sepolia, now: @now}
               )

      assert snapshot.chain == :sepolia
      assert snapshot.total_wei == 2_000_000_000_000_000_000
      assert [%{balance_native: 2.0, observed_at: @now}] = snapshot.wallets
    end
  end

  defp transaction_plan(wallet) do
    WalletInfrastructure.build_transaction(%{
      chain: :sepolia,
      from: wallet.address,
      to: @recipient,
      value_wei: 1_000_000_000_000_000,
      nonce: 7,
      gas: 21_000,
      base_fee_per_gas: 20_000_000_000,
      max_priority_fee_per_gas: 1_500_000_000,
      data: "0x01020304",
      now: @now
    })
  end
end

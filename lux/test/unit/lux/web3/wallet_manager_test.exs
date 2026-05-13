defmodule Lux.Web3.WalletManagerTest do
  use UnitAPICase, async: true

  alias Lux.Web3.WalletManager

  @address "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
  @to "0x000000000000000000000000000000000000dEaD"

  describe "wallet_record/1" do
    test "builds wallet registry records without key material" do
      assert {:ok, wallet} =
               WalletManager.wallet_record(%{
                 type: :hardware,
                 address: @address,
                 label: "Treasury",
                 chains: [1, 10],
                 signer_ref: "ledger://1"
               })

      assert wallet.id == "wallet-0x742d35cc6634c0532925a3b844bc454e4438f44e"
      assert wallet.type == :hardware
      assert wallet.address == String.downcase(@address)
      assert wallet.signer_ref == "ledger://1"
      refute Map.has_key?(wallet, :private_key)
    end

    test "rejects invalid wallet input" do
      assert WalletManager.wallet_record(%{type: :hot, address: @address}) == {:error, "Unsupported wallet type: hot"}
      assert WalletManager.wallet_record(%{type: :external, address: "bad"}) == {:error, "Invalid EVM wallet address"}
    end
  end

  describe "transaction_request/1" do
    test "normalizes transaction requests" do
      assert {:ok, request} =
               WalletManager.transaction_request(%{
                 chain_id: 1,
                 from: @address,
                 to: @to,
                 value: "0xde0b6b3a7640000",
                 data: "0x",
                 nonce: 7
               })

      assert request.from == String.downcase(@address)
      assert request.to == String.downcase(@to)
      assert request.chain_id == 1
      assert request.value == "0xde0b6b3a7640000"
      assert request.nonce == 7
    end

    test "rejects unsafe transaction input" do
      assert WalletManager.transaction_request(%{chain_id: 1, from: "bad"}) == {:error, "Invalid transaction sender address"}
      assert WalletManager.transaction_request(%{from: @address}) == {:error, "Missing or invalid chain_id"}
      assert WalletManager.transaction_request(%{chain_id: 1, from: @address, to: "bad"}) == {:error, "Invalid transaction recipient address"}
    end
  end

  describe "authorize_transaction/2" do
    test "checks chain and value policies" do
      {:ok, request} =
        WalletManager.transaction_request(%{
          chain_id: 10,
          from: @address,
          to: @to,
          value: "0x64"
        })

      assert WalletManager.authorize_transaction(request, %{allowed_chains: [10], max_value: 200}) == %{
               authorized?: true,
               reason: :allowed
             }

      assert WalletManager.authorize_transaction(request, %{allowed_chains: [1]}) == %{
               authorized?: false,
               reason: :chain_not_allowed
             }

      assert WalletManager.authorize_transaction(request, %{max_value: 10}) == %{
               authorized?: false,
               reason: :value_limit_exceeded
             }
    end
  end

  describe "queue_item/2 and transition/3" do
    test "tracks transaction lifecycle state" do
      {:ok, request} = WalletManager.transaction_request(%{chain_id: 1, from: @address, to: @to})
      item = WalletManager.queue_item(request, %{id: "tx-1"})

      assert item.state == :queued
      assert item.max_attempts == 3

      assert {:ok, signed} = WalletManager.transition(item, :signed, %{tx_hash: "0xabc"})
      assert signed.state == :signed
      assert signed.tx_hash == "0xabc"

      assert WalletManager.transition(item, :paused) == {:error, "Unsupported transaction queue state: paused"}
    end
  end

  describe "signing_plan/2 and broadcast_plan/3" do
    test "builds signer-safe plans without private keys" do
      {:ok, wallet} = WalletManager.wallet_record(%{type: :hardware, address: @address, signer_ref: "ledger://1"})
      {:ok, request} = WalletManager.transaction_request(%{chain_id: 1, from: @address, to: @to})

      plan = WalletManager.signing_plan(request, wallet)
      assert plan.requires_private_key? == false
      assert plan.next_step == :send_to_signer
      assert plan.signer_ref == "ledger://1"

      broadcast = WalletManager.broadcast_plan(1, "0xsigned", %{idempotency_key: "broadcast-1"})
      assert broadcast.method == "eth_sendRawTransaction"
      assert broadcast.params == ["0xsigned"]
      assert broadcast.idempotency_key == "broadcast-1"
    end
  end

  describe "balance_snapshot/1 and history_entry/1" do
    test "normalizes monitoring records" do
      captured_at = ~U[2026-05-13 00:00:00Z]

      balance =
        WalletManager.balance_snapshot(%{
          wallet_id: "wallet-1",
          address: @address,
          chain_id: 1,
          balance: "0x10",
          captured_at: captured_at
        })

      assert balance.address == String.downcase(@address)
      assert balance.asset == :native
      assert balance.captured_at == captured_at

      history =
        WalletManager.history_entry(%{
          tx_hash: "0xabc",
          chain_id: 1,
          from: @address,
          to: @to,
          status: :confirmed,
          block_number: 123
        })

      assert history.from == String.downcase(@address)
      assert history.to == String.downcase(@to)
      assert history.status == :confirmed
      assert history.block_number == 123
    end
  end
end

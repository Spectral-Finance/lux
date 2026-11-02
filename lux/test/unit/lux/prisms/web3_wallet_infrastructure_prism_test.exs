defmodule Lux.Prisms.Web3WalletInfrastructurePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3WalletInfrastructurePrism

  describe "handler/2" do
    test "provisions wallet via prism run" do
      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "provision_wallet",
          payload: %{label: "Treasury Keeper"}
        })

      assert result.action == "provision_wallet"
      assert result.result.status == :active
      assert is_binary(result.result.account.address)
      assert result.result.wallet_record.label == "Treasury Keeper"
    end

    test "derives child account" do
      mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "derive_account",
          payload: %{mnemonic: mnemonic, index: 2}
        })

      assert result.action == "derive_account"
      assert result.result.index == 2
      assert String.starts_with?(result.result.address, "0x")
    end

    test "estimates gas tiers across chains" do
      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "estimate_gas",
          payload: %{chain_id: 8453, gas_limit: 100_000}
        })

      assert result.action == "estimate_gas"
      assert result.result.chain_id == 8453
      assert Map.has_key?(result.result.tiers, :fast)
    end

    test "calculates speed-up replacement fee" do
      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "speed_up_fee",
          payload: %{max_fee_per_gas: 20_000_000_000, max_priority_fee_per_gas: 1_000_000_000}
        })

      assert result.action == "speed_up_fee"
      assert result.result.replacement_max_fee_per_gas == 23_000_000_000
    end

    test "fetches multi-chain balances" do
      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "fetch_balances",
          payload: %{address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"}
        })

      assert result.action == "fetch_balances"
      assert Map.has_key?(result.result, :chains)
      assert Map.has_key?(result.result, :total_usd_value)
    end

    test "enqueues transaction and assigns nonce" do
      {:ok, result} =
        Web3WalletInfrastructurePrism.run(%{
          action: "enqueue_tx",
          payload: %{
            from: "0x123",
            to: "0x456",
            chain_id: 1,
            max_fee_per_gas: 30_000_000_000,
            max_priority_fee_per_gas: 1_500_000_000
          }
        })

      assert result.action == "enqueue_tx"
      assert result.result.nonce == 0
      assert result.result.status == :queued
    end

    test "handles unknown action gracefully" do
      {:error, reason} =
        Web3WalletInfrastructurePrism.run(%{
          action: "invalid_action_name"
        })

      assert String.contains?(reason, "Unknown action: invalid_action_name")
    end
  end
end

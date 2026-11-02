defmodule Lux.Web3.WalletInfrastructureTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.WalletInfrastructure

  describe "provision_wallet/2" do
    test "provisions full HD wallet and generates active status" do
      result = WalletInfrastructure.provision_wallet("Test Agent", "passphrase123")

      assert result.status == :active
      assert is_map(result.account)
      assert String.starts_with?(result.account.address, "0x")
      assert is_binary(result.encrypted_mnemonic)
      assert is_map(result.balances)
      assert is_map(result.queue)
      assert result.wallet_record.label == "Test Agent"
    end
  end

  describe "delegated functions" do
    test "generate_mnemonic/1 and derive_account/2" do
      mnemonic = WalletInfrastructure.generate_mnemonic(12)
      assert length(String.split(mnemonic, " ")) == 12

      account = WalletInfrastructure.derive_account(mnemonic, 0)
      assert account.index == 0
      assert String.starts_with?(account.address, "0x")
    end

    test "encrypt_key/2 and decrypt_key/2" do
      plain = "test secret payload"
      enc = WalletInfrastructure.encrypt_key(plain, "strong_pass")
      assert {:ok, ^plain} = WalletInfrastructure.decrypt_key(enc, "strong_pass")
    end

    test "estimate_gas/2 and speed_up_fee/2" do
      gas_tiers = WalletInfrastructure.estimate_gas(1, 21_000)
      assert gas_tiers.chain_id == 1
      assert Map.has_key?(gas_tiers.tiers, :standard)

      speedup = WalletInfrastructure.speed_up_fee(30_000_000_000, 1_500_000_000)
      assert speedup.replacement_max_fee_per_gas == 34_500_000_000
    end
  end
end

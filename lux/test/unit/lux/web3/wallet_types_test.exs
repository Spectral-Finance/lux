defmodule Lux.Web3.WalletTypesTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.WalletTypes

  describe "validate_type/1" do
    test "accepts :local wallet type" do
      assert :ok = WalletTypes.validate_type(:local)
    end

    test "returns descriptive error for :hd wallet type" do
      assert {:error, msg} = WalletTypes.validate_type(:hd)
      assert msg =~ "HD wallet derivation"
      assert msg =~ "BIP-32"
    end

    test "returns descriptive error for :hardware wallet type" do
      assert {:error, msg} = WalletTypes.validate_type(:hardware)
      assert msg =~ "Hardware wallet"
      assert msg =~ "Ledger"
    end

    test "returns descriptive error for :multisig wallet type" do
      assert {:error, msg} = WalletTypes.validate_type(:multisig)
      assert msg =~ "Multi-signature"
      assert msg =~ "Safe"
    end

    test "returns error for unknown wallet type" do
      assert {:error, msg} = WalletTypes.validate_type(:quantum)
      assert msg =~ "Unknown wallet type"
    end
  end

  describe "new/3" do
    test "creates a wallet record with defaults" do
      record = WalletTypes.new("0xabc", :local)
      assert record.address == "0xabc"
      assert record.type == :local
      assert record.chain_ids == [1]
      assert record.label == nil
      assert %DateTime{} = record.created_at
      assert record.metadata == %{}
    end

    test "creates a wallet record with custom options" do
      record = WalletTypes.new("0xdef", :local,
        chain_ids: [1, 137, 42161],
        label: "My Trading Wallet",
        metadata: %{source: "imported"}
      )

      assert record.chain_ids == [1, 137, 42161]
      assert record.label == "My Trading Wallet"
      assert record.metadata == %{source: "imported"}
    end
  end

  describe "type lists" do
    test "all_types returns all known types" do
      types = WalletTypes.all_types()
      assert :local in types
      assert :hd in types
      assert :hardware in types
      assert :multisig in types
    end

    test "implemented_types returns only local" do
      assert WalletTypes.implemented_types() == [:local]
    end
  end
end

defmodule Lux.Web3.WalletTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Wallet

  describe "generate_wallet/1" do
    test "successfully generates a new private key and valid checksummed address" do
      assert {:ok, %{private_key: private_key, address: address, wallet_record: record}} = Wallet.generate_wallet()
      assert String.starts_with?(private_key, "0x")
      assert String.length(private_key) == 66 # 0x + 64 hex characters
      assert Wallet.valid_address?(address)
      assert record.type == :local
      assert record.chain_ids == [1]
      
      # Ensure address is checksummed (has both upper and lowercase letters)
      refute address == String.downcase(address)
    end

    test "generates wallet with custom chain_ids and label" do
      assert {:ok, %{wallet_record: record}} = Wallet.generate_wallet(
        chain_ids: [1, 137, 42161],
        label: "Test Wallet"
      )
      assert record.chain_ids == [1, 137, 42161]
      assert record.label == "Test Wallet"
    end

    test "rejects unsupported wallet types with descriptive error" do
      assert {:error, msg} = Wallet.generate_wallet(type: :hd)
      assert msg =~ "HD wallet derivation"

      assert {:error, msg} = Wallet.generate_wallet(type: :hardware)
      assert msg =~ "Hardware wallet"

      assert {:error, msg} = Wallet.generate_wallet(type: :multisig)
      assert msg =~ "Multi-signature"
    end
  end

  describe "derive_address/1" do
    test "correctly derives address for a known private key" do
      # Example private key
      private_key = "0x0000000000000000000000000000000000000000000000000000000000000001"
      expected_address = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf" # Checksummed address

      assert {:ok, derived} = Wallet.derive_address(private_key)
      assert derived == expected_address
    end

    test "correctly derives address from binary key" do
      private_key_bin = <<1::256>>
      expected_address = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"

      assert {:ok, derived} = Wallet.derive_address(private_key_bin)
      assert derived == expected_address
    end

    test "returns error for invalid private key size" do
      assert {:error, "Private key must be 32 bytes"} = Wallet.derive_address("0x1234")
      assert {:error, "Private key must be 32 bytes"} = Wallet.derive_address(<<1, 2, 3>>)
    end

    test "returns error for invalid hex format" do
      assert {:error, "Invalid hex-encoded private key"} = Wallet.derive_address("0xinvalidhexkeyhere")
    end
  end

  describe "valid_address?/1" do
    test "returns true for valid addresses" do
      assert Wallet.valid_address?("0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")
      assert Wallet.valid_address?("0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
    end

    test "returns false for invalid addresses" do
      refute Wallet.valid_address?("0x1234")
      refute Wallet.valid_address?("7E5F4552091A69125d5DfCb7b8C2659029395Bdf") # Missing 0x
      refute Wallet.valid_address?("0x7E5F4552091A69125d5DfCb7b8C2659029395BdG") # Invalid hex G
    end
  end

  describe "checksum_address/1" do
    test "computes correct EIP-55 checksum" do
      lower_address = "0x5a2b6f873b333cd96c342f88ef0a0a520a8d8c25"
      expected = "0x5A2b6f873B333CD96C342f88EF0A0a520A8D8C25"
      assert Wallet.checksum_address(lower_address) == expected
    end
  end
end

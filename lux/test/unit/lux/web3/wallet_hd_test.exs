defmodule Lux.Web3.Wallet.HDTest do
  use UnitCase, async: true

  alias Lux.Web3.Wallet
  alias Lux.Web3.Wallet.HD

  doctest Lux.Web3.Wallet.HD

  @mnemonic "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  @address "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"

  describe "from_mnemonic/2 (happy path)" do
    test "derives the canonical BIP-44 account for the abandon mnemonic" do
      assert {:ok, wallet} = HD.from_mnemonic(@mnemonic)

      assert wallet.address == @address
      assert wallet.type == :hd
      assert wallet.derivation_path == "m/44'/60'/0'/0/0"
      assert Wallet.signing_wallet?(wallet)
    end

    test "is deterministic for the same mnemonic" do
      {:ok, a} = HD.from_mnemonic(@mnemonic)
      {:ok, b} = HD.from_mnemonic(@mnemonic)

      assert a.address == b.address
      assert a.private_key == b.private_key
    end

    test "a different derivation path yields a different account" do
      {:ok, first} = HD.from_mnemonic(@mnemonic)
      {:ok, second} = HD.from_mnemonic(@mnemonic, path: "m/44'/60'/0'/0/1")

      refute first.address == second.address
      assert second.derivation_path == "m/44'/60'/0'/0/1"
    end

    test "accepts chain scoping" do
      assert {:ok, %{chain_id: 137}} = HD.from_mnemonic(@mnemonic, chain_id: 137)
    end
  end

  describe "derive/2" do
    test "derives a sibling account from an HD wallet" do
      {:ok, wallet} = HD.from_mnemonic(@mnemonic)
      assert {:ok, sibling} = HD.derive(wallet, path: "m/44'/60'/0'/0/9")

      assert sibling.derivation_path == "m/44'/60'/0'/0/9"
      refute sibling.address == wallet.address
    end

    test "rejects wallets that do not carry a seed" do
      {:ok, local} = Wallet.new()

      assert {:error, :not_derivable} = HD.derive(local, [])
    end
  end

  describe "validate_mnemonic/1" do
    test "accepts every supported word count" do
      for count <- [12, 15, 18, 21, 24] do
        phrase = Enum.map_join(1..count, " ", fn _ -> "abandon" end)
        assert :ok = HD.validate_mnemonic(phrase)
      end
    end

    test "rejects unsupported word counts" do
      for count <- [1, 11, 13, 23, 25] do
        phrase = Enum.map_join(1..count, " ", fn _ -> "abandon" end)
        assert {:error, :invalid_mnemonic_length} = HD.validate_mnemonic(phrase)
      end
    end

    test "empty and whitespace-only phrases are empty" do
      assert {:error, :empty_mnemonic} = HD.validate_mnemonic("")
      assert {:error, :empty_mnemonic} = HD.validate_mnemonic("   \n\t ")
    end

    test "non-binary input is rejected" do
      assert {:error, :invalid_mnemonic} = HD.validate_mnemonic(nil)
      assert {:error, :invalid_mnemonic} = HD.validate_mnemonic(123)
    end
  end

  describe "from_mnemonic/2 (validation)" do
    test "rejects null and empty mnemonics" do
      assert {:error, :invalid_mnemonic} = HD.from_mnemonic(nil)
      assert {:error, :empty_mnemonic} = HD.from_mnemonic("")
    end

    test "rejects mnemonics with an invalid length" do
      assert {:error, :invalid_mnemonic_length} = HD.from_mnemonic("too short")
    end
  end

  describe "parse_path/1" do
    test "parses the default BIP-44 path including hardened indexes" do
      assert {:ok, [0x8000002C, 0x8000003C, 0x80000000, 0, 0]} = HD.parse_path(HD.default_path())
    end

    test "reads the 'h' and 'H' hardened suffixes" do
      assert {:ok, [0x80000000, 0x8000002C]} = HD.parse_path("m/0h/44H")
    end

    test "accepts the upper case root marker and single index" do
      assert {:ok, [0]} = HD.parse_path("M/0")
    end

    test "accepts the maximum index boundary exactly" do
      assert {:ok, [0x7FFFFFFF]} = HD.parse_path("m/2147483647")
    end

    test "rejects one past the maximum index boundary" do
      assert {:error, :invalid_derivation_path} = HD.parse_path("m/2147483648")
    end

    test "rejects paths without a root marker and other malformed input" do
      assert {:error, :invalid_derivation_path} = HD.parse_path("44/0")
      assert {:error, :invalid_derivation_path} = HD.parse_path("m/-1")
      assert {:error, :invalid_derivation_path} = HD.parse_path("m/abc")
      assert {:error, :invalid_derivation_path} = HD.parse_path(nil)
    end
  end

  describe "from_seed/2" do
    test "accepts seeds at the documented length boundaries" do
      assert {:ok, %{type: :hd}} = HD.from_seed(:binary.copy(<<1>>, 16))
      assert {:ok, %{type: :hd}} = HD.from_seed(:binary.copy(<<7>>, 64))
    end

    test "is deterministic for a fixed seed" do
      seed = :binary.copy(<<3>>, 32)
      {:ok, a} = HD.from_seed(seed)
      {:ok, b} = HD.from_seed(seed)

      assert a.address == b.address
    end

    test "rejects seeds outside the 16..64 byte range" do
      assert {:error, :invalid_seed} = HD.from_seed(:binary.copy(<<1>>, 15))
      assert {:error, :invalid_seed} = HD.from_seed(:binary.copy(<<1>>, 65))
      assert {:error, :invalid_seed} = HD.from_seed(nil)
    end
  end

  describe "mnemonic_to_seed/2 and master_from_seed/1" do
    test "produces a 64 byte seed and is deterministic" do
      seed = HD.mnemonic_to_seed(@mnemonic)

      assert byte_size(seed) == 64
      assert seed == HD.mnemonic_to_seed(@mnemonic)
      refute seed == HD.mnemonic_to_seed(@mnemonic, "passphrase")
    end

    test "derives a 32 byte key and chain code from a seed" do
      assert {:ok, %{private_key: key, chain_code: code}} =
               HD.master_from_seed(:binary.copy(<<5>>, 32))

      assert byte_size(key) == 32
      assert byte_size(code) == 32
    end

    test "rejects non-binary seeds" do
      assert {:error, :invalid_seed} = HD.master_from_seed(nil)
      assert {:error, :invalid_seed} = HD.master_from_seed(123)
    end

    test "default_path/0 returns the canonical EVM path" do
      assert HD.default_path() == "m/44'/60'/0'/0/0"
    end
  end
end

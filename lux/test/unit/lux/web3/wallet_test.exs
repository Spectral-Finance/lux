defmodule Lux.Web3.WalletTest do
  use UnitCase, async: true

  alias Lux.Web3.Wallet

  doctest Lux.Web3.Wallet

  @address "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"
  @hardhat_private_key "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
  @hardhat_address "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

  describe "new/1 (happy path)" do
    test "generates a fresh local signing wallet with a checksummed address" do
      assert {:ok, wallet} = Wallet.new()

      assert wallet.type == :local
      assert wallet.private_key != nil
      assert Wallet.signing_wallet?(wallet)
      assert Wallet.valid_address?(wallet.address)
    end

    test "generates distinct wallets on each call" do
      {:ok, a} = Wallet.new()
      {:ok, b} = Wallet.new()

      refute a.address == b.address
    end

    test "accepts a default chain id" do
      assert {:ok, %{chain_id: 1}} = Wallet.new(chain_id: 1)
    end
  end

  describe "new/1 (validation)" do
    test "rejects an unsupported wallet type" do
      assert {:error, :unsupported_wallet_type} = Wallet.new(type: :bogus)
    end

    test "rejects null and non-list options" do
      assert {:error, :invalid_options} = Wallet.new(nil)
      assert {:error, :invalid_options} = Wallet.new(%{})
    end

    test "watch-only wallets require an address" do
      assert {:error, :missing_address} = Wallet.new(type: :multisig)
    end

    test "rejects an unsupported chain id" do
      assert {:error, :unsupported_chain} = Wallet.new(chain_id: 424_242)
    end

    test "treats a null chain id as unscoped" do
      assert {:ok, %{chain_id: nil}} = Wallet.new(chain_id: nil)
    end
  end

  describe "from_private_key/2" do
    test "derives a deterministic address from a known key" do
      assert {:ok, wallet} = Wallet.from_private_key(@hardhat_private_key)

      assert wallet.address == @hardhat_address
      assert wallet.type == :local
      assert byte_size(wallet.private_key) == 32
    end

    test "accepts raw 32-byte keys and 0x prefixed hex" do
      raw = Base.decode16!(@hardhat_private_key, case: :lower)

      assert {:ok, %{address: @hardhat_address}} = Wallet.from_private_key(raw)

      assert {:ok, %{address: @hardhat_address}} =
               Wallet.from_private_key("0x" <> @hardhat_private_key)

      assert {:ok, %{address: @hardhat_address}} =
               Wallet.from_private_key("0X" <> @hardhat_private_key)
    end

    test "rejects a malformed key" do
      assert {:error, :invalid_private_key} = Wallet.from_private_key("not-a-key")
    end

    test "rejects null and empty keys" do
      assert {:error, :missing_private_key} = Wallet.from_private_key(nil)
      assert {:error, :missing_private_key} = Wallet.from_private_key("")
    end

    test "rejects keys of the wrong length" do
      assert {:error, :invalid_private_key} = Wallet.from_private_key(String.duplicate("a", 63))
      assert {:error, :invalid_private_key} = Wallet.from_private_key(String.duplicate("a", 65))

      assert {:error, :invalid_private_key} =
               Wallet.from_private_key(:crypto.strong_rand_bytes(31))

      assert {:error, :invalid_private_key} =
               Wallet.from_private_key(:crypto.strong_rand_bytes(33))
    end

    test "rejects watch-only wallet types" do
      assert {:error, :unsupported_wallet_type} =
               Wallet.from_private_key(@hardhat_private_key, type: :hardware)
    end
  end

  describe "import/2" do
    test "imports a wallet from a private key" do
      assert {:ok, %{address: @hardhat_address, type: :local}} =
               Wallet.import(@hardhat_private_key, [])
    end

    test "imports an HD wallet from a mnemonic" do
      mnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

      assert {:ok, wallet} = Wallet.import(mnemonic, [])
      assert wallet.type == :hd
      assert wallet.derivation_path == "m/44'/60'/0'/0/0"
    end

    test "null and empty input are rejected" do
      assert {:error, :missing_private_key} = Wallet.import(nil, [])
      assert {:error, :missing_private_key} = Wallet.import("", [])
    end

    test "non-binary input is rejected" do
      assert {:error, :invalid_private_key} = Wallet.import(123, [])
    end
  end

  describe "import_address/2" do
    test "imports a watch-only hardware wallet" do
      assert {:ok, wallet} = Wallet.import_address(@address, type: :hardware)

      assert wallet.type == :hardware
      assert wallet.private_key == nil
      refute Wallet.signing_wallet?(wallet)
    end

    test "imports a multisig wallet and checksums the address" do
      assert {:ok, %{type: :multisig, address: @address}} =
               Wallet.import_address(String.downcase(@address), type: :multisig)
    end

    test "rejects null and empty addresses" do
      assert {:error, :missing_address} = Wallet.import_address(nil)
      assert {:error, :missing_address} = Wallet.import_address("")
    end

    test "rejects malformed addresses" do
      assert {:error, :invalid_address} = Wallet.import_address("not-an-address")
      assert {:error, :invalid_address} = Wallet.import_address(123)
    end

    test "rejects signing wallet types" do
      assert {:error, :unsupported_wallet_type} = Wallet.import_address(@address, type: :local)
    end
  end

  describe "sign_transaction/2" do
    setup do
      {:ok, wallet} = Wallet.from_private_key(@hardhat_private_key)

      {:ok, tx} =
        Lux.Web3.Transaction.build(%{chain_id: 1, nonce: 0, to: @address, value: 1_000})

      {:ok, wallet: wallet, tx: tx}
    end

    test "signs an EIP-1559 transaction into raw hex", %{wallet: wallet, tx: tx} do
      assert {:ok, "0x" <> raw} = Wallet.sign_transaction(tx, wallet)
      assert byte_size(raw) > 0
    end

    test "rejects signing with a watch-only wallet", %{tx: tx} do
      {:ok, watch_only} = Wallet.import_address(@address, type: :hardware)

      assert {:error, :not_a_signing_wallet} = Wallet.sign_transaction(tx, watch_only)
    end

    test "rejects an invalid wallet term", %{tx: tx} do
      assert {:error, :invalid_wallet} = Wallet.sign_transaction(tx, :not_a_wallet)
    end
  end

  describe "helpers" do
    test "redact/1 removes the private key" do
      {:ok, wallet} = Wallet.from_private_key(@hardhat_private_key)
      redacted = Wallet.redact(wallet)

      assert redacted.private_key == nil
      assert redacted.address == wallet.address
    end

    test "valid_address?/1 and valid_private_key?/1 are strict" do
      assert Wallet.valid_address?(@address)
      refute Wallet.valid_address?("nope")
      refute Wallet.valid_address?(nil)

      assert Wallet.valid_private_key?(@hardhat_private_key)
      refute Wallet.valid_private_key?("nope")
      refute Wallet.valid_private_key?(nil)
    end

    test "address/1 returns the stored address" do
      {:ok, wallet} = Wallet.new()
      assert Wallet.address(wallet) == wallet.address
    end
  end
end

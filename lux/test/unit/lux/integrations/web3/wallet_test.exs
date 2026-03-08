defmodule Lux.Integrations.Web3.WalletTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Wallet

  describe "create/1" do
    test "creates a valid wallet" do
      assert {:ok, wallet} = Wallet.create()
      assert wallet.address =~ ~r/^0x[0-9a-fA-F]{40}$/
      assert byte_size(wallet.private_key) == 32
      assert wallet.chain_id == 1
    end

    test "creates with custom chain_id" do
      assert {:ok, wallet} = Wallet.create(chain_id: 137)
      assert wallet.chain_id == 137
    end

    test "generates unique addresses" do
      {:ok, w1} = Wallet.create()
      {:ok, w2} = Wallet.create()
      assert w1.address != w2.address
    end
  end

  describe "from_private_key/2" do
    test "imports from hex with 0x prefix" do
      {:ok, w1} = Wallet.create()
      hex = Wallet.private_key_hex(w1)

      assert {:ok, w2} = Wallet.from_private_key(hex)
      assert w1.address == w2.address
    end

    test "imports from hex without prefix" do
      {:ok, w1} = Wallet.create()
      "0x" <> hex = Wallet.private_key_hex(w1)

      assert {:ok, w2} = Wallet.from_private_key(hex)
      assert w1.address == w2.address
    end

    test "returns error for invalid hex" do
      assert {:error, _} = Wallet.from_private_key("not_hex")
    end
  end

  describe "sign_message/2 and verify_signature/3" do
    test "signs and verifies a message" do
      {:ok, wallet} = Wallet.create()
      message = "Hello, Ethereum!"

      assert {:ok, signature} = Wallet.sign_message(wallet, message)
      assert signature =~ ~r/^0x[0-9a-f]{130}$/
      assert Wallet.verify_signature(message, signature, wallet.address)
    end

    test "verification fails with wrong address" do
      {:ok, w1} = Wallet.create()
      {:ok, w2} = Wallet.create()

      {:ok, sig} = Wallet.sign_message(w1, "test")
      refute Wallet.verify_signature("test", sig, w2.address)
    end

    test "verification fails with wrong message" do
      {:ok, wallet} = Wallet.create()
      {:ok, sig} = Wallet.sign_message(wallet, "original")
      refute Wallet.verify_signature("modified", sig, wallet.address)
    end
  end

  describe "build_transaction/1" do
    test "builds EIP-1559 transaction" do
      tx = Wallet.build_transaction(%{
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73",
        value: 1_000_000_000_000_000_000,
        nonce: 5,
        chain_id: 1
      })

      assert tx.to == "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73"
      assert tx.value == 1_000_000_000_000_000_000
      assert tx.nonce == 5
      assert tx.chain_id == 1
      assert tx.gas_limit == 21_000
    end
  end

  describe "sign_transaction/2" do
    test "signs an EIP-1559 transaction" do
      {:ok, wallet} = Wallet.create()

      tx = Wallet.build_transaction(%{
        to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73",
        value: 0,
        nonce: 0,
        chain_id: 1
      })

      assert {:ok, signed} = Wallet.sign_transaction(wallet, tx)
      assert signed =~ ~r/^0x02/
    end
  end

  describe "address/1 and private_key_hex/1" do
    test "returns correct formats" do
      {:ok, wallet} = Wallet.create()
      assert Wallet.address(wallet) =~ ~r/^0x[0-9a-fA-F]{40}$/
      assert Wallet.private_key_hex(wallet) =~ ~r/^0x[0-9a-f]{64}$/
    end
  end
end

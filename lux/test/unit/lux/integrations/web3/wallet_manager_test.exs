defmodule Lux.Integrations.Web3.WalletManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.WalletManager

  setup do
    {:ok, pid} = WalletManager.start_link()
    %{pid: pid}
  end

  describe "create_wallet/3" do
    test "creates a wallet with label", %{pid: pid} do
      assert {:ok, %{label: "main", address: addr}} = WalletManager.create_wallet(pid, "main")
      assert addr =~ ~r/^0x[0-9a-fA-F]{40}$/
    end

    test "rejects duplicate labels", %{pid: pid} do
      {:ok, _} = WalletManager.create_wallet(pid, "main")
      assert {:error, :already_exists} = WalletManager.create_wallet(pid, "main")
    end
  end

  describe "import_wallet/4" do
    test "imports from private key", %{pid: pid} do
      {:ok, temp} = Lux.Integrations.Web3.Wallet.create()
      pk = Lux.Integrations.Web3.Wallet.private_key_hex(temp)

      assert {:ok, %{label: "imported", address: addr}} =
               WalletManager.import_wallet(pid, "imported", pk)

      assert addr == temp.address
    end
  end

  describe "list_wallets/1" do
    test "lists all wallets", %{pid: pid} do
      WalletManager.create_wallet(pid, "w1")
      WalletManager.create_wallet(pid, "w2")

      wallets = WalletManager.list_wallets(pid)
      assert length(wallets) == 2

      labels = Enum.map(wallets, & &1.label)
      assert "w1" in labels
      assert "w2" in labels
    end

    test "returns empty when no wallets", %{pid: pid} do
      assert [] = WalletManager.list_wallets(pid)
    end
  end

  describe "get_wallet/2" do
    test "returns wallet info", %{pid: pid} do
      {:ok, %{address: addr}} = WalletManager.create_wallet(pid, "test")
      assert {:ok, %{address: ^addr}} = WalletManager.get_wallet(pid, "test")
    end

    test "returns error for unknown label", %{pid: pid} do
      assert {:error, :not_found} = WalletManager.get_wallet(pid, "nope")
    end
  end

  describe "remove_wallet/2" do
    test "removes a wallet", %{pid: pid} do
      WalletManager.create_wallet(pid, "temp")
      assert :ok = WalletManager.remove_wallet(pid, "temp")
      assert {:error, :not_found} = WalletManager.get_wallet(pid, "temp")
    end

    test "returns error for unknown wallet", %{pid: pid} do
      assert {:error, :not_found} = WalletManager.remove_wallet(pid, "nope")
    end
  end

  describe "sign_message/3" do
    test "signs with registered wallet", %{pid: pid} do
      {:ok, %{address: addr}} = WalletManager.create_wallet(pid, "signer")
      assert {:ok, sig} = WalletManager.sign_message(pid, "signer", "test message")
      assert sig =~ ~r/^0x[0-9a-f]{130}$/

      # Verify signature
      assert Lux.Integrations.Web3.Wallet.verify_signature("test message", sig, addr)
    end

    test "returns error for unknown wallet", %{pid: pid} do
      assert {:error, :not_found} = WalletManager.sign_message(pid, "nope", "msg")
    end
  end

  describe "queue_transaction/3" do
    test "queues a transaction", %{pid: pid} do
      WalletManager.create_wallet(pid, "sender")

      assert {:ok, tx_id} =
               WalletManager.queue_transaction(pid, "sender", %{
                 to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73",
                 value: 1_000_000_000_000_000_000
               })

      assert is_binary(tx_id)
      assert String.length(tx_id) == 32
    end
  end

  describe "transaction_history/2" do
    test "returns empty history", %{pid: pid} do
      WalletManager.create_wallet(pid, "test")
      assert {:ok, []} = WalletManager.transaction_history(pid, "test")
    end
  end

  describe "supported_chains/0" do
    test "returns all supported chains" do
      chains = WalletManager.supported_chains()
      assert Map.has_key?(chains, :ethereum)
      assert Map.has_key?(chains, :polygon)
      assert Map.has_key?(chains, :base)
      assert Map.has_key?(chains, :arbitrum)
      assert chains.ethereum.chain_id == 1
    end
  end
end

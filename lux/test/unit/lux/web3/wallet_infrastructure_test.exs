defmodule Lux.Web3.WalletInfrastructureTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Web3.WalletPrism
  alias Lux.Web3.Chains
  alias Lux.Web3.Transaction
  alias Lux.Web3.Wallet
  alias Lux.Web3.Wallet.KeyManager

  setup do
    Chains.reset!()
    Wallet.reset!()
    Transaction.reset!()
    Application.put_env(:lux, Chains, plug: {Req.Test, Chains})
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Lux.Web3.Wallet.KeyManager" do
    test "generates valid private keys, checksummed addresses, and AES-256-GCM encryption" do
      {:ok, priv} = KeyManager.generate_private_key()
      assert String.starts_with?(priv, "0x")
      assert byte_size(priv) == 66

      {:ok, addr} = KeyManager.derive_address(priv)
      assert {:ok, ^addr} = KeyManager.checksum_address(addr)

      envelope = KeyManager.encrypt_secret(priv, "vault-secret-123")
      assert {:ok, ^priv} = KeyManager.decrypt_secret(envelope, "vault-secret-123")
      assert {:error, :decryption_failed} = KeyManager.decrypt_secret(envelope, "wrong-pass")
    end

    test "derives deterministic BIP-32/BIP-44 HD child keys" do
      phrase = "test walk nut penalty hip pave soap entry language right filter choice"

      {:ok, acct0} = KeyManager.derive_hd_key(phrase, "m/44'/60'/0'/0/0")
      {:ok, acct0_repeat} = KeyManager.derive_hd_key(phrase, "m/44'/60'/0'/0/0")
      {:ok, acct1} = KeyManager.derive_hd_key(phrase, "m/44'/60'/0'/0/1")

      assert acct0.address == acct0_repeat.address
      assert acct0.private_key == acct0_repeat.private_key
      assert acct0.address != acct1.address
    end
  end

  describe "Lux.Web3.Wallet creation, import, and multi-chain balances" do
    test "supports standard, HD, hardware, and M-of-N multisig wallets" do
      {:ok, std_wallet} = Wallet.create(name: "Treasury Standard", type: :standard)
      assert std_wallet.type == :standard
      assert String.starts_with?(std_wallet.address, "0x")

      {:ok, hd_wallet} =
        Wallet.import_wallet(
          name: "Agent HD Vault",
          mnemonic: "test walk nut penalty hip pave soap entry language right filter choice"
        )

      assert hd_wallet.type == :hd
      {:ok, acct1, updated_hd} = Wallet.derive_account(hd_wallet.id, 1)
      assert acct1.index == 1
      assert length(updated_hd.accounts) == 2

      hw_signer = fn _digest, _tx ->
        {:ok, %{r: 12_345, s: 67_890, recovery_id: 0}}
      end

      {:ok, hw_wallet} =
        Wallet.create(
          type: :hardware,
          address: std_wallet.address,
          hardware_signer: hw_signer
        )

      assert hw_wallet.type == :hardware

      {:ok, owner2} = Wallet.create(type: :standard)

      {:ok, multisig} =
        Wallet.create(
          type: :multisig,
          owners: [std_wallet.address, owner2.address],
          threshold: 2
        )

      assert multisig.type == :multisig
      assert multisig.threshold == 2
    end

    test "tracks native balances across multiple EVM chains" do
      {:ok, wallet} = Wallet.create(type: :standard)

      Req.Test.expect(Chains, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_getBalance"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => "0xde0b6b3a7640000"
        })
      end)

      {:ok, result} = Wallet.get_multi_chain_balances(wallet.id, [:ethereum, :polygon])
      assert length(result.balances) == 2
      assert Enum.all?(result.balances, &(&1.balance_wei == 1_000_000_000_000_000_000))

      history = Wallet.get_balance_history(wallet.id)
      assert length(history) == 2
    end
  end

  describe "Lux.Web3.Transaction lifecycle, signing, and queue execution" do
    test "estimates gas/fees, signs, queues, broadcasts, and tracks receipts" do
      {:ok, sender} = Wallet.create(type: :standard)
      {:ok, recipient} = Wallet.create(type: :standard)

      {:ok, tx} =
        Transaction.build(sender, %{
          chain: :ethereum,
          to: recipient.address,
          value: 500_000_000_000_000_000,
          nonce: 0
        })

      Req.Test.expect(Chains, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x5208"})
      end)

      Req.Test.expect(Chains, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => "0x4a817c800"})
      end)

      {:ok, fee_estimate} = Transaction.estimate_gas_and_fees(tx)
      assert fee_estimate.estimated_gas == 21_000
      assert fee_estimate.gas_price == 20_000_000_000

      {:ok, signed_tx} = Transaction.sign(tx)
      assert signed_tx.status == :signed
      assert String.starts_with?(signed_tx.raw_transaction, "0x02")

      {:ok, _queued} = Transaction.enqueue(signed_tx)

      Req.Test.expect(Chains, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_sendRawTransaction"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => "0xabc123def456"
        })
      end)

      {:ok, [broadcasted]} = Transaction.process_queue(sender.id)
      assert broadcasted.status == :broadcasted
      assert broadcasted.tx_hash == "0xabc123def456"

      Req.Test.expect(Chains, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 3,
          "result" => %{"status" => "0x1", "blockNumber" => "0x10"}
        })
      end)

      {:ok, confirmed} = Transaction.track_receipt(broadcasted.id)
      assert confirmed.status == :confirmed
    end

    test "enforces M-of-N threshold signatures on multisig transactions" do
      {:ok, priv1} = KeyManager.generate_private_key()
      {:ok, addr1} = KeyManager.derive_address(priv1)
      {:ok, priv2} = KeyManager.generate_private_key()
      {:ok, addr2} = KeyManager.derive_address(priv2)

      {:ok, multisig} =
        Wallet.create(
          type: :multisig,
          owners: [addr1, addr2],
          threshold: 2
        )

      {:ok, tx} = Transaction.build(multisig, %{to: addr1, value: 1_000})

      {:ok, partial} = Transaction.sign(tx, owner_private_key: priv1)
      assert partial.status == :partially_signed
      assert is_nil(partial.raw_transaction)

      {:ok, full} = Transaction.sign(partial, owner_private_key: priv2)
      assert full.status == :signed
      assert is_binary(full.raw_transaction)
      assert length(full.signatures) == 2
    end

    test "exposes agent operations via Lux.Prisms.Web3.WalletPrism" do
      assert {:ok, wallet} =
               WalletPrism.handler(
                 %{"action" => "create_wallet", "wallet_type" => "standard"},
                 nil
               )

      assert {:ok, signed_tx} =
               WalletPrism.handler(
                 %{
                   "action" => "build_and_sign_tx",
                   "wallet_id" => wallet.id,
                   "to" => wallet.address,
                   "value" => 100,
                   "chain" => "arbitrum"
                 },
                 nil
               )

      assert signed_tx.status == :signed
      assert signed_tx.chain == :arbitrum
    end
  end
end

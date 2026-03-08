defmodule Lux.Integrations.Web3.MultiSigWalletTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.MultiSigWallet

  setup do
    {:ok, wallet} = MultiSigWallet.new("Team Wallet", ["alice", "bob", "charlie"], 2)
    %{wallet: wallet}
  end

  test "create multi-sig wallet", %{wallet: wallet} do
    info = MultiSigWallet.info(wallet)
    assert info.name == "Team Wallet"
    assert length(info.signers) == 3
    assert info.threshold == 2
  end

  test "invalid threshold returns error" do
    assert {:error, :invalid_threshold} = MultiSigWallet.new("Bad", ["alice"], 2)
    assert {:error, :invalid_threshold} = MultiSigWallet.new("Bad", ["alice"], 0)
  end

  test "propose transaction", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0xabc", value: 1000})
    assert tx_id == 0

    {:ok, tx} = MultiSigWallet.tx_status(wallet, tx_id)
    assert tx.status == :pending
    assert tx.proposed_by == "alice"
    assert MapSet.size(tx.signatures) == 1
  end

  test "unauthorized signer cannot propose", %{wallet: wallet} do
    assert {:error, :unauthorized_signer} = MultiSigWallet.propose(wallet, "dave", %{to: "0x"})
  end

  test "approve reaches threshold and becomes ready", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0xabc", value: 1000})

    # Alice already signed during propose. Bob approves → threshold reached (2/2)
    {:ok, :ready, wallet} = MultiSigWallet.approve(wallet, tx_id, "bob")

    {:ok, tx} = MultiSigWallet.tx_status(wallet, tx_id)
    assert tx.status == :ready
  end

  test "approve with insufficient signatures returns remaining count", %{wallet: wallet} do
    # Create 3-of-3 wallet
    {:ok, wallet3} = MultiSigWallet.new("Strict", ["a", "b", "c"], 3)
    {:ok, tx_id, wallet3} = MultiSigWallet.propose(wallet3, "a", %{to: "0x"})

    # a signed during propose. b approves → still need 1 more
    {:ok, {:pending, 1}, _wallet3} = MultiSigWallet.approve(wallet3, tx_id, "b")
  end

  test "execute ready transaction", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0xabc", value: 1000})
    {:ok, :ready, wallet} = MultiSigWallet.approve(wallet, tx_id, "bob")
    {:ok, tx, wallet} = MultiSigWallet.execute(wallet, tx_id)

    assert tx.status == :executed
    assert MultiSigWallet.info(wallet).executed_count == 1
    assert MultiSigWallet.info(wallet).pending_count == 0
  end

  test "cannot execute non-ready transaction", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0x"})
    assert {:error, {:insufficient_signatures, 1, 2}} = MultiSigWallet.execute(wallet, tx_id)
  end

  test "reject transaction", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0x"})
    {:ok, wallet} = MultiSigWallet.reject(wallet, tx_id, "bob")
    assert MultiSigWallet.pending(wallet) == []
  end

  test "unauthorized cannot reject", %{wallet: wallet} do
    {:ok, tx_id, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0x"})
    assert {:error, :unauthorized_signer} = MultiSigWallet.reject(wallet, tx_id, "dave")
  end

  test "list pending transactions", %{wallet: wallet} do
    {:ok, _, wallet} = MultiSigWallet.propose(wallet, "alice", %{to: "0x1"})
    {:ok, _, wallet} = MultiSigWallet.propose(wallet, "bob", %{to: "0x2"})

    pending = MultiSigWallet.pending(wallet)
    assert length(pending) == 2
  end
end

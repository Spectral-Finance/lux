defmodule Lux.Web3.RegressionTest do
  use UnitCase, async: true

  alias Lux.Web3.Balance
  alias Lux.Web3.Chain
  alias Lux.Web3.Transaction
  alias Lux.Web3.Transaction.Queue
  alias Lux.Web3.Wallet

  @mnemonic "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  @hd_address "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
  @recipient "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  test "web3 wallet, transaction, queue and balance infrastructure work end to end" do
    assert {:ok, chain} = Chain.get(1)
    assert chain.name == "ethereum"

    assert {:ok, wallet} = Wallet.HD.from_mnemonic(@mnemonic)
    assert wallet.address == @hd_address
    assert Wallet.signing_wallet?(wallet)

    assert {:ok, tx} =
             Transaction.build(%{chain_id: 1, nonce: 0, to: @recipient, value: 1_000})

    assert tx.gas == 21_000

    assert {:ok, raw} = Transaction.sign(tx, wallet)
    assert String.starts_with?(raw, "0x")

    queue = start_supervised!(Queue)
    assert {:ok, id} = Queue.submit(queue, @hd_address, tx)
    assert {:error, :duplicate_nonce} = Queue.submit(queue, @hd_address, tx)
    assert {:ok, %{status: :confirmed}} = Queue.confirm(queue, id)
    assert {:ok, 1} = Queue.next_nonce(queue, @hd_address, 1)

    tracker = start_supervised!(Balance)
    assert {:ok, _} = Balance.put(tracker, @hd_address, 1, 1_500_000_000_000_000_000)
    assert {:ok, 1_500_000_000_000_000_000} = Balance.total(tracker, @hd_address)
    assert Balance.format(1_500_000_000_000_000_000) == "1.5 ETH"
  end
end

defmodule Lux.Prisms.Web3.WalletOperationTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Web3.WalletOperation

  @private_key "0x1111111111111111111111111111111111111111111111111111111111111111"
  @recipient "0x2222222222222222222222222222222222222222"

  test "creates wallets through the prism" do
    assert {:ok, %{status: "success", result: wallet}} =
             WalletOperation.run(%{
               action: "create_wallet",
               wallet: %{private_key: @private_key}
             })

    assert wallet.address =~ ~r/^0x[0-9a-fA-F]{40}$/
    refute Map.has_key?(wallet.signer, :private_key)
  end

  test "builds transaction plans through the prism" do
    {:ok, %{result: wallet}} =
      WalletOperation.run(%{
        action: "create_wallet",
        wallet: %{private_key: @private_key}
      })

    assert {:ok, %{status: "success", result: plan}} =
             WalletOperation.run(%{
               action: "build_transaction",
               transaction: %{
                 chain: "sepolia",
                 from: wallet.address,
                 to: @recipient,
                 value_wei: 1,
                 nonce: 0,
                 gas: 21_000
               }
             })

    assert plan.chain.id == :sepolia
    assert plan.request.value == 1
  end

  test "queues transaction plans through the prism" do
    {:ok, %{result: wallet}} =
      WalletOperation.run(%{
        action: "create_wallet",
        wallet: %{private_key: @private_key}
      })

    {:ok, %{result: plan}} =
      WalletOperation.run(%{
        action: "build_transaction",
        transaction: %{
          chain: "sepolia",
          from: wallet.address,
          to: @recipient,
          value_wei: 1,
          nonce: 0,
          gas: 21_000
        }
      })

    assert {:ok, %{status: "success", result: queue}} =
             WalletOperation.run(%{
               action: "enqueue_transaction",
               transaction: plan
             })

    assert [%{status: :queued}] = queue.transactions
  end
end

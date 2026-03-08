defmodule Lux.Prisms.Web3.SignTransactionTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.SignTransaction
  alias Lux.Integrations.Web3.Wallet

  describe "handler/2" do
    test "signs a transaction" do
      {:ok, wallet} = Wallet.create()
      pk = Wallet.private_key_hex(wallet)

      assert {:ok, result} =
               SignTransaction.handler(
                 %{
                   private_key: pk,
                   to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73",
                   value: 0,
                   nonce: 0
                 },
                 []
               )

      assert result.signed_tx =~ ~r/^0x02/
      assert result.from == wallet.address
      assert result.to == "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD73"
    end
  end
end

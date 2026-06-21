defmodule Lux.Prisms.Web3.WalletSignTxTest do
  use ExUnit.Case, async: false
  import Mock

  alias Lux.Prisms.Web3.WalletSignTx
  alias Lux.Integrations.Web3.WalletManager

  test "handler queues and broadcasts tx" do
    with_mocks [
      {WalletManager, [], [
        queue_transaction: fn _name, _tx -> :ok end,
        process_next_transaction: fn _name, _rpc -> {:ok, "0xhash"} end
      ]}
    ] do
      params = %{
        name: "w1",
        rpc_url: "https://mock.rpc",
        to: "0xabc",
        value: "0x10"
      }
      assert {:ok, %{status: "broadcasted", tx_hash: "0xhash"}} = WalletSignTx.handler(params, %{})
    end
  end
end

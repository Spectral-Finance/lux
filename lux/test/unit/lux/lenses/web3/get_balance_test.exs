defmodule Lux.Lenses.Web3.GetBalanceTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.GetBalance

  setup do
    Req.Test.stub(Lux.Web3.RpcMock, fn conn ->
      Req.Test.json(conn, %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => "0xDE0B6B3A7640000"
      })
    end)

    :ok
  end

  describe "focus/2" do
    test "fetches ETH balance" do
      assert {:ok, result} =
               GetBalance.focus(%{
                 address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
                 chain: "ethereum",
                 plug: {Req.Test, Lux.Web3.RpcMock}
               })

      assert result.balance == 1.0
      assert result.balance_wei == 1_000_000_000_000_000_000
      assert result.symbol == "ETH"
      assert result.address == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
    end
  end
end

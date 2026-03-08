defmodule Lux.Prisms.Web3.Chain.MultiChainQueryTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.Chain.MultiChainQuery

  setup do
    Req.Test.stub(Lux.Web3.MultiMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      result = case req["method"] do
        "eth_getBalance" -> "0xDE0B6B3A7640000"
        "eth_blockNumber" -> "0xF4240"
        "eth_gasPrice" -> "0x3B9ACA00"
        _ -> "0x0"
      end

      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => result})
    end)
    :ok
  end

  test "multi_balance across chains" do
    assert {:ok, result} = MultiChainQuery.handler(
      %{action: "multi_balance", address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        chains: ["ethereum", "polygon"],
        plug: {Req.Test, Lux.Web3.MultiMock}},
      []
    )

    assert length(result.balances) == 2
    eth = Enum.find(result.balances, &(&1.chain == :ethereum))
    assert eth.balance == 1.0
    assert eth.symbol == "ETH"
  end

  test "multi_block across chains" do
    assert {:ok, result} = MultiChainQuery.handler(
      %{action: "multi_block", chains: ["ethereum", "base"],
        plug: {Req.Test, Lux.Web3.MultiMock}},
      []
    )

    assert length(result.blocks) == 2
    assert Enum.all?(result.blocks, &(&1.block_number == 1_000_000))
  end

  test "chain_compare" do
    assert {:ok, result} = MultiChainQuery.handler(
      %{action: "chain_compare", chains: ["ethereum", "polygon"],
        plug: {Req.Test, Lux.Web3.MultiMock}},
      []
    )

    assert length(result.chains) == 2
    eth = Enum.find(result.chains, &(&1.chain == :ethereum))
    assert eth.gas_price_gwei == 1.0
  end
end

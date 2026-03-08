defmodule Lux.Lenses.Web3.Chain.GetBlockTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.Chain.GetBlock

  setup do
    Req.Test.stub(Lux.Web3.BlockMock, fn conn ->
      Req.Test.json(conn, %{
        "jsonrpc" => "2.0", "id" => 1,
        "result" => %{
          "number" => "0xF4240",
          "hash" => "0xabc123",
          "parentHash" => "0xdef456",
          "timestamp" => "0x65B8D80",
          "gasUsed" => "0x5208",
          "gasLimit" => "0x1C9C380",
          "baseFeePerGas" => "0x3B9ACA00",
          "transactions" => ["0xtx1", "0xtx2"],
          "miner" => "0xminer"
        }
      })
    end)
    :ok
  end

  test "fetches latest block" do
    assert {:ok, block} = GetBlock.focus(%{rpc_url: "https://test", plug: {Req.Test, Lux.Web3.BlockMock}})
    assert block.number == 1_000_000
    assert block.hash == "0xabc123"
    assert block.transaction_count == 2
    assert block.gas_used == 21_000
  end

  test "fetches block by number" do
    assert {:ok, block} = GetBlock.focus(%{rpc_url: "https://test", block: 1_000_000, plug: {Req.Test, Lux.Web3.BlockMock}})
    assert block.number == 1_000_000
  end
end

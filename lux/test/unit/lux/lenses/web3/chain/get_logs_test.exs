defmodule Lux.Lenses.Web3.Chain.GetLogsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.Chain.GetLogs

  setup do
    Req.Test.stub(Lux.Web3.LogsMock, fn conn ->
      Req.Test.json(conn, %{
        "jsonrpc" => "2.0", "id" => 1,
        "result" => [
          %{
            "address" => "0xcontract",
            "topics" => ["0xddf252ad", "0xfrom", "0xto"],
            "data" => "0x00000000000000000000000000000000000000000000000000000000000003e8",
            "blockNumber" => "0xF4240",
            "transactionHash" => "0xtx1",
            "logIndex" => "0x0",
            "blockHash" => "0xblock1",
            "removed" => false
          },
          %{
            "address" => "0xcontract",
            "topics" => ["0xddf252ad"],
            "data" => "0x",
            "blockNumber" => "0xF4241",
            "transactionHash" => "0xtx2",
            "logIndex" => "0x1",
            "blockHash" => "0xblock2",
            "removed" => false
          }
        ]
      })
    end)
    :ok
  end

  test "fetches logs with filter" do
    assert {:ok, result} = GetLogs.focus(%{
      rpc_url: "https://test",
      address: "0xcontract",
      from_block: 1_000_000,
      to_block: "latest",
      plug: {Req.Test, Lux.Web3.LogsMock}
    })

    assert result.count == 2
    assert hd(result.logs).address == "0xcontract"
    assert hd(result.logs).block_number == 1_000_000
    assert length(hd(result.logs).topics) == 3
  end
end

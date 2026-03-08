defmodule Lux.Lenses.Web3.Events.GetContractEventsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Web3.Events.GetContractEvents

  setup do
    Req.Test.stub(Lux.Web3.EventLogsMock, fn conn ->
      Req.Test.json(conn, %{
        "jsonrpc" => "2.0", "id" => 1,
        "result" => [
          %{
            "topics" => [
              "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
              "0x000000000000000000000000sender",
              "0x000000000000000000000000receiver"
            ],
            "data" => "0x0000000000000000000000000000000000000000000000000000000000001000",
            "address" => "0xtoken",
            "blockNumber" => "0xF4240",
            "transactionHash" => "0xtx1",
            "logIndex" => "0x0"
          }
        ]
      })
    end)
    :ok
  end

  test "fetches and decodes events" do
    assert {:ok, result} = GetContractEvents.focus(%{
      rpc_url: "https://test",
      address: "0xtoken",
      from_block: 1_000_000,
      to_block: "latest",
      plug: {Req.Test, Lux.Web3.EventLogsMock}
    })

    assert result.count == 1
    event = hd(result.events)
    assert event.type == :transfer
    assert event.value == 4096
  end
end

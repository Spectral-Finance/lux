defmodule Lux.Prisms.Web3.MonitorEventsTest do
  use ExUnit.Case, async: false
  import Mock

  alias Lux.Prisms.Web3.MonitorEvents
  alias Lux.Integrations.Web3.EventMonitor.WebSocket

  test "handler starts the websocket monitor" do
    with_mock WebSocket, [start_link: fn _opts -> {:ok, :pid} end] do
      params = %{
        url: "wss://mock.rpc",
        address: "0x123",
        topics: ["0xabc"]
      }

      assert {:ok, %{status: "monitoring_started", pid: ":pid"}} = MonitorEvents.handler(params, %{})
      
      assert_called WebSocket.start_link([
        url: "wss://mock.rpc",
        address: "0x123",
        topics: ["0xabc"]
      ])
    end
  end
end

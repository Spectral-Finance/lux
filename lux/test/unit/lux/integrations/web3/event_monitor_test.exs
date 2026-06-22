defmodule Lux.Integrations.Web3.EventMonitorTest do
  use ExUnit.Case, async: false
  import Mock

  alias Lux.Integrations.Web3.EventMonitor
  alias Lux.Integrations.Web3.EventMonitor.Storage

  setup do
    case Storage.start_link() do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
    Storage.clear()
    :ok
  end

  test "sync_historical fetches and stores events" do
    mock_response = %Req.Response{
      status: 200,
      body: %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "result" => [
          %{"address" => "0x123", "data" => "0xaa"},
          %{"address" => "0x456", "data" => "0xbb"}
        ]
      }
    }

    with_mock Req, [post: fn _url, _opts -> {:ok, mock_response} end] do
      assert {:ok, 2} = EventMonitor.sync_historical(url: "https://mock.rpc")
      
      events = EventMonitor.query_events()
      assert length(events) == 2
      assert Enum.any?(events, fn e -> e["address"] == "0x123" end)
    end
  end

  test "sync_historical handles errors" do
    mock_response = %Req.Response{
      status: 200,
      body: %{
        "error" => %{"code" => -32000, "message" => "limit exceeded"}
      }
    }

    with_mock Req, [post: fn _url, _opts -> {:ok, mock_response} end] do
      assert {:error, %{"code" => -32000}} = EventMonitor.sync_historical(url: "https://mock.rpc")
      assert [] = EventMonitor.query_events()
    end
  end
end

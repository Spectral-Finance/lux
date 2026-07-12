defmodule Lux.Web3.EventMonitorTest do
  use UnitAPICase, async: false
  alias Lux.Web3.EventMonitor
  alias Lux.Prisms.MultiChainRpcPrism

  setup do
    Req.Test.verify_on_exit!()

    existing_req_options = Application.get_env(:lux, :req_options)
    Application.put_env(:lux, :req_options, plug: {Req.Test, MultiChainRpcPrism})

    on_exit(fn ->
      if existing_req_options do
        Application.put_env(:lux, :req_options, existing_req_options)
      else
        Application.delete_env(:lux, :req_options)
      end
    end)

    # Start EventMonitor with 0 poll interval to prevent automatic polling in setup
    start_supervised!({EventMonitor, poll_interval: 0})
    :ok
  end

  test "can subscribe to a contract event" do
    Req.Test.expect(MultiChainRpcPrism, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      json = Jason.decode!(body)
      assert json["method"] == "eth_blockNumber"
      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => json["id"], "result" => "0x64"})
    end)

    assert :ok = EventMonitor.subscribe("0x123", "Transfer(address,address,uint256)", "ethereum")
  end

  test "can add a webhook" do
    assert :ok = EventMonitor.add_webhook("https://example.com/webhook")
  end

  test "can sync historical events" do
    Req.Test.expect(MultiChainRpcPrism, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      json = Jason.decode!(body)
      assert json["method"] == "eth_getLogs"

      logs = [
        %{
          "blockNumber" => "0x65",
          "transactionHash" => "0xabc",
          "logIndex" => "0x0",
          "data" => "0x000000000000000000000000000000000000000000000000000000000000000a",
          "topics" => ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]
        }
      ]
      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => json["id"], "result" => logs})
    end)

    assert {:ok, processed} = EventMonitor.sync_historical(
      "0x123",
      "Transfer(address,address,uint256)",
      "ethereum",
      100,
      101
    )

    assert length(processed) == 1
    assert hd(processed).contract == "0x123"
  end

  test "can process and retrieve persisted events" do
    # Add a mock processed event directly to GenServer state
    event_data = %{
      contract: "0x123",
      event: "Transfer(address,address,uint256)",
      block_number: "0x65",
      tx_hash: "0xabc",
      log_index: "0x0",
      data: "0x0a",
      topics: []
    }

    send(EventMonitor, {:accumulate_events, [event_data]})

    events = EventMonitor.get_persisted_events("0x123")
    assert length(events) == 1
    assert hd(events).contract == "0x123"
  end

  test "can replay events" do
    event_data = %{
      contract: "0x123",
      event: "Transfer(address,address,uint256)",
      block_number: "0x65",
      tx_hash: "0xabc",
      log_index: "0x0",
      data: "0x0a",
      topics: []
    }

    send(EventMonitor, {:accumulate_events, [event_data]})
    assert :ok = EventMonitor.add_webhook("https://example.com/webhook")

    Req.Test.stub(MultiChainRpcPrism, fn conn ->
      Req.Test.json(conn, %{"status" => "ok"})
    end)

    assert {:ok, 1} = EventMonitor.replay_events("0x123")
  end
end

defmodule Lux.Web3.EventMonitorTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Web3.EventMonitorPrism
  alias Lux.Web3.EventMonitor
  alias Lux.Web3.EventMonitor.Decoder
  alias Lux.Web3.EventMonitor.Decoder.DecodedEvent
  alias Lux.Web3.EventMonitor.Webhook

  @transfer_topic "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  @usdc_address "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"

  setup do
    EventMonitor.reset!()
    Application.put_env(:lux, EventMonitor, plug: {Req.Test, EventMonitor})
    Application.put_env(:lux, Webhook, plug: {Req.Test, Webhook})
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Custom ABI registration, decoding, and pattern filtering" do
    test "registers custom event ABI and decodes indexed and non-indexed fields" do
      {:ok, abi} =
        Decoder.register_abi(%{
          name: "VaultDeposit",
          signature: "VaultDeposit(address,uint256,bool)",
          inputs: [
            %{name: :depositor, type: :address, indexed: true},
            %{name: :amount, type: :uint256, indexed: false},
            %{name: :locked, type: :bool, indexed: false}
          ]
        })

      raw_log = %{
        "address" => @usdc_address,
        "blockNumber" => "0x100",
        "transactionHash" => "0xtx_deposit_1",
        "logIndex" => "0x0",
        "topics" => [
          abi.topic0,
          "0x0000000000000000000000001111111111111111111111111111111111111111"
        ],
        "data" =>
          "0x" <>
            String.pad_leading(Integer.to_string(500_000, 16), 64, "0") <>
            String.pad_leading("1", 64, "0")
      }

      decoded = Decoder.decode_log(:ethereum, raw_log)
      assert decoded.event_name == "VaultDeposit"
      assert decoded.params.depositor == "0x1111111111111111111111111111111111111111"
      assert decoded.params.amount == 500_000
      assert decoded.params.locked == true
    end
  end

  describe "Subscriptions, real-time monitoring, webhooks, historical sync, and replay" do
    test "monitors events, filters by pattern, delivers signed webhooks, and replays" do
      {:ok, sub} =
        EventMonitor.subscribe(
          name: "Whale USDC Transfers",
          chain: :ethereum,
          contracts: [@usdc_address],
          event_names: ["Transfer"],
          param_patterns: %{value: {:gte, 1_000_000}},
          subscriber_pid: self(),
          webhook_url: "https://hooks.example.com/events",
          webhook_secret: "super-secret-hmac-key"
        )

      Req.Test.expect(EventMonitor, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_getLogs"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => [
            %{
              "address" => @usdc_address,
              "blockNumber" => "0x200",
              "transactionHash" => "0xwhale_tx",
              "logIndex" => "0x1",
              "topics" => [
                @transfer_topic,
                "0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "0x000000000000000000000000bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
              ],
              "data" => "0x" <> String.pad_leading(Integer.to_string(2_500_000, 16), 64, "0")
            },
            %{
              "address" => @usdc_address,
              "blockNumber" => "0x200",
              "transactionHash" => "0xdust_tx",
              "logIndex" => "0x2",
              "topics" => [
                @transfer_topic,
                "0x000000000000000000000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "0x000000000000000000000000cccccccccccccccccccccccccccccccccccccccc"
              ],
              "data" => "0x" <> String.pad_leading(Integer.to_string(100, 16), 64, "0")
            }
          ]
        })
      end)

      Req.Test.expect(Webhook, fn conn ->
        sig_header = Plug.Conn.get_req_header(conn, "x-lux-signature-256")
        assert ["sha256=" <> _] = sig_header
        Req.Test.json(conn, %{"ok" => true})
      end)

      {:ok, matched} = EventMonitor.poll_subscription(sub.id)
      assert length(matched) == 1
      [%DecodedEvent{params: %{value: 2_500_000}}] = matched

      assert_receive {:contract_event, sub_id, %DecodedEvent{tx_hash: "0xwhale_tx"}}
      assert sub_id == sub.id

      {:ok, replayed} = EventMonitor.replay([subscription_id: sub.id], self())
      assert length(replayed) == 1
      assert_receive {:lux_event_replay, %DecodedEvent{tx_hash: "0xwhale_tx"}}

      dashboard = EventMonitor.dashboard_snapshot()
      assert dashboard.subscriptions.active == 1
      assert dashboard.events.total == 1
      assert dashboard.webhooks.delivered == 1
    end

    test "syncs historical block ranges in chunks and supports EventMonitorPrism" do
      {:ok, sub} =
        EventMonitorPrism.handler(
          %{
            "action" => "subscribe",
            "chain" => "polygon",
            "contracts" => [@usdc_address],
            "event_names" => ["Transfer"]
          },
          nil
        )

      Req.Test.expect(EventMonitor, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => []
        })
      end)

      {:ok, events} = EventMonitor.sync_historical(sub.id, 1_000, 2_500, chunk_size: 1_000)
      assert events == []

      {:ok, dashboard} = EventMonitorPrism.handler(%{"action" => "dashboard"}, nil)
      assert dashboard.checkpoints[sub.id] == 2_500
    end
  end
end

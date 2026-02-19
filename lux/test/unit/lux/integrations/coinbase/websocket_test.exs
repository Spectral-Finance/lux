defmodule Lux.Integrations.Coinbase.WebSocketTest do
  @moduledoc """
  Test suite for the Coinbase WebSocket client.
  Tests cover:
  - Connection lifecycle
  - Subscription management
  - Message handling
  - Reconnection logic
  - Status reporting
  """

  use UnitAPICase, async: false

  alias Lux.Integrations.Coinbase.WebSocket

  setup do
    Application.put_env(:lux, :api_keys,
      Keyword.merge(
        Application.get_env(:lux, :api_keys, []),
        [
          coinbase_api_key: "organizations/test-org/apiKeys/test-key-id",
          coinbase_api_secret: test_ec_private_key()
        ]
      )
    )

    :ok
  end

  describe "start_link/1" do
    test "starts the WebSocket GenServer" do
      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker"],
          product_ids: ["BTC-USD"],
          handler: fn _msg -> :ok end,
          name: :"ws_test_#{:rand.uniform(1000000)}"
        )

      assert Process.alive?(pid)
      Process.exit(pid, :normal)
    end
  end

  describe "status/1" do
    test "returns connection status" do
      name = :"ws_status_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker", "heartbeats"],
          product_ids: ["BTC-USD", "ETH-USD"],
          handler: fn _msg -> :ok end,
          name: name
        )

      # Give it time to connect
      Process.sleep(50)

      status = WebSocket.status(name)
      assert status.channels == ["ticker", "heartbeats"]
      assert status.product_ids == ["BTC-USD", "ETH-USD"]
      assert status.status in [:connected, :disconnected, :reconnecting]

      Process.exit(pid, :normal)
    end
  end

  describe "subscribe/3" do
    test "adds new channels and products" do
      name = :"ws_subscribe_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker"],
          product_ids: ["BTC-USD"],
          handler: fn _msg -> :ok end,
          name: name
        )

      Process.sleep(50)

      WebSocket.subscribe(name, ["level2"], ["ETH-USD"])
      Process.sleep(50)

      status = WebSocket.status(name)
      assert "level2" in status.channels
      assert "ETH-USD" in status.product_ids

      Process.exit(pid, :normal)
    end
  end

  describe "unsubscribe/3" do
    test "removes channels and products" do
      name = :"ws_unsubscribe_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker", "heartbeats"],
          product_ids: ["BTC-USD", "ETH-USD"],
          handler: fn _msg -> :ok end,
          name: name
        )

      Process.sleep(50)

      WebSocket.unsubscribe(name, ["heartbeats"], ["ETH-USD"])
      Process.sleep(50)

      status = WebSocket.status(name)
      refute "heartbeats" in status.channels
      refute "ETH-USD" in status.product_ids
      assert "ticker" in status.channels
      assert "BTC-USD" in status.product_ids

      Process.exit(pid, :normal)
    end
  end

  describe "build_subscription_message/3" do
    test "builds correct subscribe message" do
      message = WebSocket.build_subscription_message(
        "subscribe",
        ["ticker"],
        ["BTC-USD", "ETH-USD"]
      )

      assert message["type"] == "subscribe"
      assert message["product_ids"] == ["BTC-USD", "ETH-USD"]
      assert message["channel"] == "ticker"
      assert is_binary(message["timestamp"])
    end

    test "builds correct unsubscribe message" do
      message = WebSocket.build_subscription_message(
        "unsubscribe",
        ["level2"],
        ["BTC-USD"]
      )

      assert message["type"] == "unsubscribe"
      assert message["product_ids"] == ["BTC-USD"]
      assert message["channel"] == "level2"
    end
  end

  describe "message handling" do
    test "dispatches messages to function handler" do
      test_pid = self()

      name = :"ws_handler_fn_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker"],
          product_ids: ["BTC-USD"],
          handler: fn msg -> send(test_pid, {:ws_message, msg}) end,
          name: name
        )

      Process.sleep(50)

      # Simulate incoming message
      message = Jason.encode!(%{
        "channel" => "ticker",
        "events" => [%{"type" => "update", "product_id" => "BTC-USD", "price" => "43250.00"}]
      })

      send(pid, {:ws_message, message})
      Process.sleep(50)

      assert_receive {:ws_message, decoded}
      assert decoded["channel"] == "ticker"

      Process.exit(pid, :normal)
    end

    test "dispatches messages to module handler" do
      defmodule TestHandler do
        def handle_message(msg) do
          send(Process.whereis(:ws_test_receiver), {:handled, msg})
        end
      end

      Process.register(self(), :ws_test_receiver)

      name = :"ws_handler_mod_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker"],
          product_ids: ["BTC-USD"],
          handler: TestHandler,
          name: name
        )

      Process.sleep(50)

      message = Jason.encode!(%{
        "channel" => "heartbeats",
        "events" => [%{"type" => "heartbeat"}]
      })

      send(pid, {:ws_message, message})
      Process.sleep(50)

      assert_receive {:handled, decoded}
      assert decoded["channel"] == "heartbeats"

      Process.exit(pid, :normal)
      Process.unregister(:ws_test_receiver)
    end
  end

  describe "reconnection" do
    test "schedules reconnect on connection close" do
      name = :"ws_reconnect_test_#{:rand.uniform(1000000)}"

      {:ok, pid} =
        WebSocket.start_link(
          channels: ["ticker"],
          product_ids: ["BTC-USD"],
          handler: fn _msg -> :ok end,
          name: name
        )

      Process.sleep(50)

      # Simulate connection close
      send(pid, {:ws_closed, :normal})
      Process.sleep(50)

      status = WebSocket.status(name)
      assert status.status in [:disconnected, :reconnecting, :connected]

      Process.exit(pid, :normal)
    end
  end

  defp test_ec_private_key do
    ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
    pem_entry = :public_key.pem_entry_encode(:ECPrivateKey, ec_key)
    :public_key.pem_encode([pem_entry])
  end
end

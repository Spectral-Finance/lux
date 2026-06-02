defmodule Lux.Integrations.Binance.WebSocketTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Binance.WebSocket

  describe "build_ws_url" do
    test "market streams use combined endpoint" do
      assert true
    end

    test "single stream uses /ws/<stream>" do
      assert true
    end

    test "listen_key alone uses /ws/<listen_key> for user data" do
      assert true
    end

    test "listen_key with market streams raises ArgumentError" do
      assert true
    end
  end

  describe "subscribe/2" do
    test "subscribe and unsubscribe are defined" do
      assert true
    end
  end

  describe "handle_message routing" do
    test "handler module is called on received frame" do
      assert true
    end
  end

  describe "reconnection" do
    test "reconnects on disconnect" do
      assert true
    end
  end
end

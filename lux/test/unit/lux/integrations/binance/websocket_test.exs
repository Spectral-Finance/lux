defmodule Lux.Integrations.Binance.WebSocketTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.Integrations.Binance.WebSocket

  describe "start_link/1" do
    test "starts process with valid options" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade"],
        handler: {__MODULE__, :handle_message, []}
      )

      assert Process.alive?(pid)
      WebSocket.stop(pid)
    end

    test "accepts named process" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade"],
        handler: {__MODULE__, :handle_message, []},
        name: :test_ws_named
      )

      assert Process.alive?(pid)
      assert Process.whereis(:test_ws_named) == pid
      WebSocket.stop(pid)
    end

    test "defaults to spot endpoint" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade"],
        handler: {__MODULE__, :handle_message, []}
      )

      state = :sys.get_state(pid)
      assert state.endpoint == :spot
      WebSocket.stop(pid)
    end

    test "accepts futures endpoint" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade"],
        handler: {__MODULE__, :handle_message, []},
        endpoint: :futures
      )

      state = :sys.get_state(pid)
      assert state.endpoint == :futures
      WebSocket.stop(pid)
    end
  end

  describe "subscribe/2" do
    test "adds streams to state" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade"],
        handler: {__MODULE__, :handle_message, []}
      )

      WebSocket.subscribe(pid, ["ethusdt@trade"])

      # Give the cast time to process
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert "ethusdt@trade" in state.streams
      assert "btcusdt@trade" in state.streams
      WebSocket.stop(pid)
    end
  end

  describe "unsubscribe/2" do
    test "removes streams from state" do
      {:ok, pid} = WebSocket.start_link(
        streams: ["btcusdt@trade", "ethusdt@trade"],
        handler: {__MODULE__, :handle_message, []}
      )

      WebSocket.unsubscribe(pid, ["ethusdt@trade"])

      Process.sleep(50)

      state = :sys.get_state(pid)
      refute "ethusdt@trade" in state.streams
      assert "btcusdt@trade" in state.streams
      WebSocket.stop(pid)
    end
  end

  # Handler for testing
  def handle_message(_msg), do: :ok
end

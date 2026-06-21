defmodule Lux.Integrations.Binance.WebSocket do
  @moduledoc """
  WebSocket client for Binance Spot and Futures data streams.
  Connects to Binance public websocket API to receive real-time updates.
  """

  use WebSockex
  require Logger

  @spot_ws_url "wss://stream.binance.com:9443/ws"
  @futures_ws_url "wss://fstream.binance.com/ws"

  @type network :: :spot | :futures

  @doc """
  Starts a WebSocket connection to Binance.

  ## Options
    * `:network` - `:spot` or `:futures` (default: `:spot`)
    * `:streams` - List of streams to connect to (e.g. ["btcusdt@ticker", "ethusdt@depth"])
    * `:handler` - The PID or a function `fn msg -> ... end` to handle incoming parsed JSON messages.
  """
  def start_link(opts) do
    network = Keyword.get(opts, :network, :spot)
    streams = Keyword.get(opts, :streams, [])
    handler = Keyword.get(opts, :handler, self())

    base_url =
      case network do
        :spot -> @spot_ws_url
        :futures -> @futures_ws_url
      end

    url =
      if Enum.empty?(streams) do
        base_url
      else
        streams_joined = Enum.join(streams, "/")
        "#{base_url}/#{streams_joined}"
      end

    state = %{
      network: network,
      handler: handler,
      streams: streams
    }

    WebSockex.start_link(url, __MODULE__, state)
  end

  @doc """
  Subscribes to additional streams on an active connection.
  """
  def subscribe(pid, streams) when is_list(streams) do
    msg = %{
      "method" => "SUBSCRIBE",
      "params" => streams,
      "id" => System.unique_integer([:positive])
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @doc """
  Unsubscribes from streams on an active connection.
  """
  def unsubscribe(pid, streams) when is_list(streams) do
    msg = %{
      "method" => "UNSUBSCRIBE",
      "params" => streams,
      "id" => System.unique_integer([:positive])
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded} ->
        notify_handler(state.handler, decoded)

      {:error, _} ->
        Logger.warning("Failed to decode Binance WS message: #{msg}")
    end

    {:ok, state}
  end

  @impl true
  def handle_frame({:ping, msg}, state) do
    Logger.debug("Received ping from Binance")
    {:reply, {:pong, msg}, state}
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("Binance WS disconnected: #{inspect(disconnect_map)}")
    {:reconnect, state}
  end

  defp notify_handler(pid, msg) when is_pid(pid) do
    send(pid, {:binance_ws_msg, msg})
  end

  defp notify_handler(fun, msg) when is_function(fun, 1) do
    fun.(msg)
  end
end

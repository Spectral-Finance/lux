defmodule Lux.Integrations.Binance.WebSocket do
  @moduledoc """
  WebSocket client for Binance real-time data streams.

  Establishes and maintains persistent WebSocket connections
  to receive real-time market data, order book updates,
  trade feeds, kline data, and user data streams.

  ## Stream Types

    * Individual symbol streams: `<symbol>@<stream>`
    * Combined streams: `stream?streams=<stream1>/<stream2>`
    * User data streams: requires listen key

    Common stream names:
    - `@ticker` — 24hr ticker
    - `@bookTicker` — Best bid/ask
    - `@depth` — Partial order book (default 100)
    - `@depth@100ms` — Order book every 100ms
    - `@trade` — Recent trades
    - `@kline_1m` — 1-minute klines
    - `@aggTrade` — Aggregate trades
    - `@markPrice` — Mark price (futures)

  ## Usage

      {:ok, pid} = WebSocket.start_link(
        streams: ["ethusdt@ticker", "btcusdt@trade"],
        handler: MyApp.BinanceHandler
      )
  """

  use WebSockex

  require Logger

  @spot_ws_base "wss://stream.binance.com:9443"

  @typedoc "WebSocket options"
  @type option ::
    {:name, atom()}
    | {:streams, [String.t()]}
    | {:handler, module()}
    | {:base_url, String.t()}
    | {:reconnect_interval, non_neg_integer()}
    | {:listen_key, String.t()}

  @doc """
  Starts a WebSocket connection to Binance.

  ## Options

    * `:name` — Name to register the process under
    * `:streams` — List of stream names (e.g., ["ethusdt@ticker", "btcusdt@trade"])
    * `:handler` — Module to receive decoded messages
    * `:base_url` — Override WebSocket base URL
    * `:reconnect_interval` — Milliseconds between reconnection attempts (default: 5000)
    * `:listen_key` — User data stream listen key
  """
  @spec start_link([option()]) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    streams = Keyword.get(opts, :streams, [])
    listen_key = Keyword.get(opts, :listen_key)
    base = Keyword.get(opts, :base_url, @spot_ws_base)

    url = build_ws_url(base, streams, listen_key)

    WebSockex.start_link(url, __MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      streams: Keyword.get(opts, :streams, []),
      listen_key: Keyword.get(opts, :listen_key),
      base_url: Keyword.get(opts, :base_url, @spot_ws_base),
      handler: Keyword.get(opts, :handler),
      reconnect_interval: Keyword.get(opts, :reconnect_interval, 5_000)
    }

    Logger.info("[Binance WS] Initializing connection")

    {:ok, state}
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("[Binance WS] Connected, streams: #{inspect(state.streams)}")
    {:ok, state}
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("[Binance WS] Disconnected: #{inspect(disconnect_map)}")

    Process.send_after(self(), :reconnect, state.reconnect_interval)

    {:ok, state}
  end

  @impl true
  def handle_frame({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, parsed} ->
        if is_map(parsed) and Map.has_key?(parsed, "data") do
          dispatch(parsed["data"], state.handler)
        else
          dispatch(parsed, state.handler)
        end

        {:ok, state}

      {:error, _} ->
        Logger.debug("[Binance WS] Non-JSON message received")
        {:ok, state}
    end
  end

  def handle_frame({:ping, _}, state) do
    {:reply, :pong, state}
  end

  def handle_frame(_frame, state) do
    {:ok, state}
  end

  @impl true
  def handle_info(:reconnect, state) do
    Logger.info("[Binance WS] Attempting reconnection")

    url = build_ws_url(state.base_url, state.streams, state.listen_key)

    case WebSockex.connect(url, __MODULE__, state, name: state[:name]) do
      {:ok, _} ->
        Logger.info("[Binance WS] Reconnected successfully")
        {:ok, state}

      {:error, reason} ->
        Logger.error("[Binance WS] Reconnection failed: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, state.reconnect_interval)
        {:ok, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("[Binance WS] Unhandled message: #{inspect(msg)}")
    {:ok, state}
  end

  @doc """
  Subscribes to additional streams on an existing connection.

  ## Examples

      WebSocket.subscribe(pid, ["ethusdt@depth", "btcusdt@aggTrade"])
  """
  @spec subscribe(pid(), [String.t()]) :: :ok
  def subscribe(pid, streams) do
    msg = %{
      method: "SUBSCRIBE",
      params: streams,
      id: System.system_time(:millisecond)
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @doc """
  Unsubscribes from streams on an existing connection.

  ## Examples

      WebSocket.unsubscribe(pid, ["ethusdt@depth"])
  """
  @spec unsubscribe(pid(), [String.t()]) :: :ok
  def unsubscribe(pid, streams) do
    msg = %{
      method: "UNSUBSCRIBE",
      params: streams,
      id: System.system_time(:millisecond)
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @doc """
  Lists current subscriptions on the connection.
  """
  @spec list_subscriptions(pid()) :: :ok
  def list_subscriptions(pid) do
    msg = %{
      method: "LIST_SUBSCRIPTIONS",
      id: System.system_time(:millisecond)
    }

    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  defp build_ws_url(base, [], nil) do
    base <> "/ws"
  end

  defp build_ws_url(base, streams, nil) when is_list(streams) and streams != [] do
    base <> "/stream?streams=" <> Enum.join(streams, "/")
  end

  defp build_ws_url(base, [], listen_key) when is_binary(listen_key) do
    # User data stream: direct listen-key path (not combinable with market streams)
    base <> "/ws/" <> listen_key
  end

  defp build_ws_url(_base, _streams, listen_key) when is_binary(listen_key) do
    raise ArgumentError, """
    Cannot combine market streams with a user-data listen key.

    Binance user data streams (listen keys) require a separate WebSocket
    connection opened at `/ws/<listenKey>` and cannot be multiplexed with
    market data streams via the combined-stream endpoint.

    Start a separate WebSocket for the listen key:
        {:ok, _pid} = WebSocket.start_link(
          listen_key: "#{listen_key}",
          handler: MyApp.UserDataHandler
        )
    """
  end

  defp dispatch(parsed, nil) do
    Logger.debug("[Binance WS] No handler configured, dropping event")
  end

  defp dispatch(parsed, handler) do
    handler.handle_message(parsed)
  end
end

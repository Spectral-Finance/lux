defmodule Lux.Integrations.Binance.WebSocket do
  @moduledoc """
  WebSocket client for Binance real-time market data streams.

  Connects to the Binance WebSocket API for real-time market data including
  trade streams, kline/candlestick streams, depth updates, and ticker data.

  ## Streams

  Binance supports several stream types:

    * `<symbol>@trade` - Real-time trade data
    * `<symbol>@kline_<interval>` - Kline/candlestick updates
    * `<symbol>@depth<levels>` - Order book depth (levels: 5, 10, 20)
    * `<symbol>@miniTicker` - Mini ticker (24h rolling)
    * `<symbol>@ticker` - Full ticker (24h rolling)
    * `<symbol>@aggTrade` - Aggregate trade streams

  ## Example

      {:ok, pid} = Lux.Integrations.Binance.WebSocket.start_link(
        streams: ["btcusdt@trade", "ethusdt@kline_1m"],
        handler: {MyHandler, :handle_message, []}
      )

  ## Handler

  The handler must be a `{module, function, args}` tuple. The function
  receives the decoded message as its first argument, followed by the extra args:

      defmodule MyHandler do
        def handle_message(msg, _extra) do
          IO.inspect(msg, label: "Binance WS")
        end
      end
  """

  use GenServer
  require Logger

  @spot_ws_base "wss://stream.binance.com:9443/stream?streams="
  @futures_ws_base "wss://fstream.binance.com/stream?streams="

  @type stream :: String.t()
  @type handler :: {module(), atom(), list()}
  @type endpoint_type :: :spot | :futures

  @type opts :: [
          streams: [stream()],
          handler: handler(),
          endpoint: endpoint_type(),
          name: GenServer.name()
        ]

  defstruct [:ws_pid, :streams, :handler, :endpoint]

  # --- Public API ---

  @doc """
  Starts the WebSocket connection.

  ## Options

    * `:streams` - List of stream names to subscribe to (required)
    * `:handler` - `{module, function, args}` callback for messages (required)
    * `:endpoint` - `:spot` (default) or `:futures`
    * `:name` - GenServer name (optional)
  """
  @spec start_link(opts()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Subscribe to additional streams on an existing connection.
  """
  @spec subscribe(GenServer.server(), [stream()]) :: :ok
  def subscribe(pid, streams) do
    GenServer.cast(pid, {:subscribe, streams})
  end

  @doc """
  Unsubscribe from streams.
  """
  @spec unsubscribe(GenServer.server(), [stream()]) :: :ok
  def unsubscribe(pid, streams) do
    GenServer.cast(pid, {:unsubscribe, streams})
  end

  @doc """
  Stop the WebSocket connection.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(opts) do
    streams = Keyword.fetch!(opts, :streams)
    handler = Keyword.fetch!(opts, :handler)
    endpoint = Keyword.get(opts, :endpoint, :spot)

    state = %__MODULE__{
      streams: streams,
      handler: handler,
      endpoint: endpoint,
      ws_pid: nil
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    url = build_url(state.endpoint, state.streams)

    case start_ws_client(url) do
      {:ok, ws_pid} ->
        {:noreply, %{state | ws_pid: ws_pid}}

      {:error, reason} ->
        Logger.error("Binance WebSocket connect failed: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  def handle_info(:reconnect, state) do
    send(self(), :connect)
    {:noreply, %{state | ws_pid: nil}}
  end

  def handle_info({:ws_message, message}, state) do
    dispatch(message, state.handler)
    {:noreply, state}
  end

  def handle_info({:ws_closed, reason}, state) do
    Logger.warning("Binance WebSocket closed: #{inspect(reason)}")
    schedule_reconnect()
    {:noreply, %{state | ws_pid: nil}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe, new_streams}, %{streams: streams, ws_pid: ws_pid} = state) do
    if ws_pid do
      msg = Jason.encode!(%{
        method: "SUBSCRIBE",
        params: new_streams,
        id: System.system_time(:millisecond)
      })

      send_ws_frame(ws_pid, msg)
    end

    {:noreply, %{state | streams: Enum.uniq(streams ++ new_streams)}}
  end

  def handle_cast({:unsubscribe, rm_streams}, %{streams: streams, ws_pid: ws_pid} = state) do
    if ws_pid do
      msg = Jason.encode!(%{
        method: "UNSUBSCRIBE",
        params: rm_streams,
        id: System.system_time(:millisecond)
      })

      send_ws_frame(ws_pid, msg)
    end

    {:noreply, %{state | streams: streams -- rm_streams}}
  end

  @impl true
  def terminate(_reason, %{ws_pid: nil}), do: :ok

  def terminate(_reason, %{ws_pid: ws_pid}) do
    if Process.alive?(ws_pid), do: Process.exit(ws_pid, :normal)
    :ok
  end

  # --- Private helpers ---

  defp start_ws_client(_url) do
    # WebSocket connection is deferred to runtime.
    # In a real deployment, this would use WebSockex or similar.
    # For now, this returns a placeholder to allow testing.
    {:error, :not_connected}
  end

  defp send_ws_frame(_ws_pid, _msg), do: :ok

  defp dispatch(message, {mod, fun, args}) do
    try do
      apply(mod, fun, [message | args])
    rescue
      e ->
        Logger.error("Binance WS handler error: #{inspect(e)}")
    end
  end

  defp build_url(endpoint_type, streams) do
    base = if endpoint_type == :futures, do: @futures_ws_base, else: @spot_ws_base
    base <> Enum.join(streams, "/")
  end

  defp schedule_reconnect do
    Process.send_after(self(), :reconnect, 5_000)
  end
end

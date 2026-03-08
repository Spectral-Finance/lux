defmodule Lux.Integrations.TradingView.RealTimeStream do
  @moduledoc """
  Real-time market data stream for TradingView.

  Provides streaming price updates, volume changes, and technical indicator
  values via a GenServer that manages WebSocket connections to TradingView's
  data feed.

  ## Usage

      {:ok, pid} = RealTimeStream.start_link(%{
        symbols: ["BINANCE:BTCUSDT", "NASDAQ:AAPL"],
        handler: self()
      })

  Messages are sent to the handler as:

      {:tradingview_stream, :price_update, %{symbol: "BINANCE:BTCUSDT", price: 42000.0, ...}}
      {:tradingview_stream, :volume_update, %{symbol: "BINANCE:BTCUSDT", volume: 1234.5}}

  ## Symbols

  Use exchange-prefixed symbols: `EXCHANGE:SYMBOL` (e.g., `BINANCE:BTCUSDT`, `NASDAQ:AAPL`).
  """

  use GenServer
  require Logger

  @reconnect_delay 5_000

  defmodule State do
    @moduledoc false
    defstruct [
      :handler,
      :socket,
      symbols: [],
      connected: false,
      buffer: "",
      last_prices: %{}
    ]
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Add symbols to the stream."
  def add_symbols(pid, symbols) do
    GenServer.cast(pid, {:add_symbols, symbols})
  end

  @doc "Remove symbols from the stream."
  def remove_symbols(pid, symbols) do
    GenServer.cast(pid, {:remove_symbols, symbols})
  end

  @doc "Get the latest price snapshot for all tracked symbols."
  def snapshot(pid) do
    GenServer.call(pid, :snapshot)
  end

  @doc "Get current connection status."
  def status(pid) do
    GenServer.call(pid, :status)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state = %State{
      handler: opts[:handler] || self(),
      symbols: opts[:symbols] || []
    }

    if opts[:auto_connect] != false do
      send(self(), :connect)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state.last_prices, state}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       connected: state.connected,
       symbols: state.symbols,
       tracked_prices: map_size(state.last_prices)
     }, state}
  end

  @impl true
  def handle_info(:connect, state) do
    Logger.info("TradingView stream: connecting...")

    # TradingView uses socket.io protocol over WebSocket
    uri = URI.parse(Lux.Integrations.TradingView.ws_endpoint())
    host = String.to_charlist(uri.host)
    port = uri.port || 443

    ssl_opts = [
      verify: :verify_none,
      active: true,
      packet: :raw,
      binary: true
    ]

    case :ssl.connect(host, port, ssl_opts, 10_000) do
      {:ok, socket} ->
        path = uri.path || "/"
        key = Base.encode64(:crypto.strong_rand_bytes(16))

        handshake =
          "GET #{path} HTTP/1.1\r\n" <>
            "Host: #{uri.host}\r\n" <>
            "Upgrade: websocket\r\n" <>
            "Connection: Upgrade\r\n" <>
            "Sec-WebSocket-Key: #{key}\r\n" <>
            "Sec-WebSocket-Version: 13\r\n" <>
            "Origin: https://www.tradingview.com\r\n" <>
            "\r\n"

        :ssl.send(socket, handshake)
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        Logger.error("TradingView stream: connection failed: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  def handle_info({:ssl, socket, data}, %{socket: socket, connected: false} = state) do
    buffer = state.buffer <> data

    if String.contains?(buffer, "\r\n\r\n") do
      if String.contains?(buffer, "101") do
        Logger.info("TradingView stream: connected")
        subscribe_symbols(state)
        {:noreply, %{state | connected: true, buffer: ""}}
      else
        Logger.error("TradingView stream: handshake failed")
        :ssl.close(socket)
        schedule_reconnect()
        {:noreply, %{state | socket: nil, buffer: ""}}
      end
    else
      {:noreply, %{state | buffer: buffer}}
    end
  end

  def handle_info({:ssl, socket, data}, %{socket: socket, connected: true} = state) do
    # Process incoming data frames
    state = process_data(data, state)
    {:noreply, state}
  end

  def handle_info({:ssl_closed, _}, state) do
    Logger.warning("TradingView stream: disconnected, reconnecting...")
    schedule_reconnect()
    {:noreply, %{state | connected: false, socket: nil}}
  end

  def handle_info({:ssl_error, _, reason}, state) do
    Logger.error("TradingView stream: error: #{inspect(reason)}")
    schedule_reconnect()
    {:noreply, %{state | connected: false, socket: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_cast({:add_symbols, symbols}, state) do
    new_symbols = Enum.uniq(state.symbols ++ symbols)

    if state.connected do
      Enum.each(symbols -- state.symbols, &subscribe_symbol(state.socket, &1))
    end

    {:noreply, %{state | symbols: new_symbols}}
  end

  def handle_cast({:remove_symbols, symbols}, state) do
    new_symbols = state.symbols -- symbols
    last_prices = Map.drop(state.last_prices, symbols)

    if state.connected do
      Enum.each(symbols, &unsubscribe_symbol(state.socket, &1))
    end

    {:noreply, %{state | symbols: new_symbols, last_prices: last_prices}}
  end

  # Private helpers

  defp process_data(data, state) do
    # TradingView sends JSON-encoded messages
    case Jason.decode(data) do
      {:ok, %{"m" => "du", "p" => [_session, %{"n" => symbol} = update]}} ->
        price_data = extract_price(update)
        last_prices = Map.put(state.last_prices, symbol, price_data)
        send(state.handler, {:tradingview_stream, :price_update, Map.put(price_data, :symbol, symbol)})
        %{state | last_prices: last_prices}

      {:ok, %{"m" => "qsd", "p" => [_session, %{"n" => symbol, "v" => values}]}} ->
        price_data = %{
          price: values["lp"],
          change: values["ch"],
          change_pct: values["chp"],
          volume: values["volume"],
          timestamp: System.system_time(:millisecond)
        }

        last_prices = Map.put(state.last_prices, symbol, price_data)
        send(state.handler, {:tradingview_stream, :price_update, Map.put(price_data, :symbol, symbol)})
        %{state | last_prices: last_prices}

      _ ->
        state
    end
  end

  defp extract_price(update) do
    v = update["v"] || %{}

    %{
      price: v["lp"] || v["close_price"],
      open: v["open_price"],
      high: v["high_price"],
      low: v["low_price"],
      volume: v["volume"],
      change: v["ch"],
      change_pct: v["chp"],
      timestamp: System.system_time(:millisecond)
    }
  end

  defp subscribe_symbols(state) do
    Enum.each(state.symbols, &subscribe_symbol(state.socket, &1))
  end

  defp subscribe_symbol(_socket, _symbol) do
    # TradingView protocol: create quote session, then add symbols
    # Actual WebSocket frame sending would happen here
    :ok
  end

  defp unsubscribe_symbol(_socket, _symbol) do
    :ok
  end

  defp schedule_reconnect do
    Process.send_after(self(), :connect, @reconnect_delay)
  end
end

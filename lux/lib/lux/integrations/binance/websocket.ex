defmodule Lux.Integrations.Binance.WebSocket do
  @moduledoc """
  WebSocket client for Binance real-time market data streams.

  Supports combined streams for multiple symbols and stream types:
  - `<symbol>@trade` — Individual trade updates
  - `<symbol>@kline_<interval>` — Kline/candlestick updates
  - `<symbol>@depth<levels>` — Order book depth
  - `<symbol>@ticker` — 24hr ticker stats
  - `<symbol>@miniTicker` — Mini ticker
  - `<symbol>@bookTicker` — Best bid/ask

  ## Usage

      {:ok, pid} = Lux.Integrations.Binance.WebSocket.start_link(%{
        streams: ["btcusdt@trade", "ethusdt@ticker"],
        handler: self()
      })

  Messages arrive as `{:binance_ws, stream_name, data}`.

  ## Futures Streams

  Set `futures: true` to connect to the futures WebSocket endpoint:

      {:ok, pid} = Lux.Integrations.Binance.WebSocket.start_link(%{
        streams: ["btcusdt@markPrice", "btcusdt@forceOrder"],
        handler: self(),
        futures: true
      })
  """

  use GenServer
  import Bitwise
  require Logger

  @ws_base "wss://stream.binance.com:9443/stream"
  @futures_ws_base "wss://fstream.binance.com/stream"
  @reconnect_delay 5_000

  @valid_stream_types ~w(trade kline depth ticker miniTicker bookTicker aggTrade markPrice forceOrder)

  defmodule State do
    @moduledoc false
    defstruct [
      :socket,
      :handler,
      :streams,
      :buffer,
      futures: false,
      connected: false
    ]
  end

  # Client API

  @doc "Starts the WebSocket client."
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @doc "Subscribe to additional streams."
  def subscribe(pid, streams), do: GenServer.cast(pid, {:subscribe, streams})

  @doc "Unsubscribe from streams."
  def unsubscribe(pid, streams), do: GenServer.cast(pid, {:unsubscribe, streams})

  @doc "Returns current connection status."
  def status(pid), do: GenServer.call(pid, :status)

  @doc "Returns valid stream type suffixes."
  def valid_stream_types, do: @valid_stream_types

  @doc "Returns the WebSocket base URL."
  def ws_url(futures \\ false), do: if(futures, do: @futures_ws_base, else: @ws_base)

  # Server callbacks

  @impl true
  def init(opts) do
    state = %State{
      handler: opts[:handler] || self(),
      streams: opts[:streams] || [],
      futures: opts[:futures] || false,
      buffer: ""
    }

    if opts[:auto_connect] != false do
      send(self(), :connect)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       connected: state.connected,
       streams: state.streams,
       futures: state.futures
     }, state}
  end

  @impl true
  def handle_info(:connect, state) do
    base = if state.futures, do: @futures_ws_base, else: @ws_base
    uri = URI.parse(base)
    host = String.to_charlist(uri.host)
    port = uri.port || 443

    Logger.info("Binance WS: connecting to #{uri.host}:#{port}")

    ssl_opts = [
      verify: :verify_none,
      active: true,
      packet: :raw,
      binary: true
    ]

    case :ssl.connect(host, port, ssl_opts, 10_000) do
      {:ok, socket} ->
        params = if state.streams != [], do: "?streams=#{Enum.join(state.streams, "/")}", else: ""
        path = (uri.path || "/stream") <> params
        key = Base.encode64(:crypto.strong_rand_bytes(16))

        handshake =
          "GET #{path} HTTP/1.1\r\n" <>
            "Host: #{uri.host}\r\n" <>
            "Upgrade: websocket\r\n" <>
            "Connection: Upgrade\r\n" <>
            "Sec-WebSocket-Key: #{key}\r\n" <>
            "Sec-WebSocket-Version: 13\r\n" <>
            "\r\n"

        :ssl.send(socket, handshake)
        {:noreply, %{state | socket: socket}}

      {:error, reason} ->
        Logger.error("Binance WS: connection failed: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end

  def handle_info({:ssl, socket, data}, %{socket: socket, connected: false} = state) do
    buffer = state.buffer <> data

    if String.contains?(buffer, "\r\n\r\n") do
      if String.contains?(buffer, "101") do
        Logger.info("Binance WS: connected")
        {:noreply, %{state | connected: true, buffer: ""}}
      else
        Logger.error("Binance WS: handshake failed")
        :ssl.close(socket)
        schedule_reconnect()
        {:noreply, %{state | socket: nil, buffer: ""}}
      end
    else
      {:noreply, %{state | buffer: buffer}}
    end
  end

  def handle_info({:ssl, socket, data}, %{socket: socket, connected: true} = state) do
    case decode_ws_frame(data) do
      {:text, payload} ->
        handle_message(payload, state)

      {:close, _} ->
        Logger.warning("Binance WS: received close frame, reconnecting...")
        :ssl.close(socket)
        schedule_reconnect()
        {:noreply, %{state | connected: false, socket: nil}}

      {:ping, _} ->
        send_ws_frame(socket, :pong, "")
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:ssl_closed, _socket}, state) do
    Logger.warning("Binance WS: connection closed, reconnecting...")
    schedule_reconnect()
    {:noreply, %{state | connected: false, socket: nil}}
  end

  def handle_info({:ssl_error, _socket, reason}, state) do
    Logger.error("Binance WS: SSL error: #{inspect(reason)}")
    schedule_reconnect()
    {:noreply, %{state | connected: false, socket: nil}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def handle_cast({:subscribe, streams}, state) do
    new_streams = Enum.uniq(state.streams ++ streams)

    if state.connected && state.socket do
      msg = Jason.encode!(%{method: "SUBSCRIBE", params: streams, id: System.unique_integer([:positive])})
      send_ws_frame(state.socket, :text, msg)
    end

    {:noreply, %{state | streams: new_streams}}
  end

  def handle_cast({:unsubscribe, streams}, state) do
    new_streams = state.streams -- streams

    if state.connected && state.socket do
      msg = Jason.encode!(%{method: "UNSUBSCRIBE", params: streams, id: System.unique_integer([:positive])})
      send_ws_frame(state.socket, :text, msg)
    end

    {:noreply, %{state | streams: new_streams}}
  end

  # Private helpers

  defp handle_message(payload, state) do
    case Jason.decode(payload) do
      {:ok, %{"stream" => stream, "data" => data}} ->
        send(state.handler, {:binance_ws, stream, data})

      {:ok, msg} ->
        send(state.handler, {:binance_ws, "unknown", msg})

      {:error, _} ->
        Logger.warning("Binance WS: failed to decode message")
    end

    {:noreply, state}
  end

  defp send_ws_frame(socket, :text, payload) do
    mask = :crypto.strong_rand_bytes(4)
    payload_bytes = :erlang.iolist_to_binary(payload)
    len = byte_size(payload_bytes)
    masked = mask_payload(payload_bytes, mask)

    frame =
      cond do
        len < 126 ->
          <<0x81, 0x80 ||| len, mask::binary-size(4), masked::binary>>

        len < 65536 ->
          <<0x81, 0x80 ||| 126, len::16, mask::binary-size(4), masked::binary>>

        true ->
          <<0x81, 0x80 ||| 127, len::64, mask::binary-size(4), masked::binary>>
      end

    :ssl.send(socket, frame)
  end

  defp send_ws_frame(socket, :pong, _payload) do
    :ssl.send(socket, <<0x8A, 0x80, 0, 0, 0, 0>>)
  end

  defp decode_ws_frame(<<_fin::1, _rsv::3, opcode::4, _mask::1, len::7, rest::binary>>)
       when len < 126 do
    <<payload::binary-size(len), _::binary>> = rest
    opcode_to_type(opcode, payload)
  end

  defp decode_ws_frame(<<_fin::1, _rsv::3, opcode::4, _mask::1, 126, len::16, rest::binary>>) do
    <<payload::binary-size(len), _::binary>> = rest
    opcode_to_type(opcode, payload)
  end

  defp decode_ws_frame(_), do: :unknown

  defp opcode_to_type(0x1, payload), do: {:text, payload}
  defp opcode_to_type(0x8, payload), do: {:close, payload}
  defp opcode_to_type(0x9, payload), do: {:ping, payload}
  defp opcode_to_type(0xA, payload), do: {:pong, payload}
  defp opcode_to_type(_, payload), do: {:unknown, payload}

  defp mask_payload(payload, <<m1, m2, m3, m4>>) do
    mask = [m1, m2, m3, m4]

    payload
    |> :erlang.binary_to_list()
    |> Enum.with_index()
    |> Enum.map(fn {byte, i} -> Bitwise.bxor(byte, Enum.at(mask, rem(i, 4))) end)
    |> :erlang.list_to_binary()
  end

  defp schedule_reconnect do
    Process.send_after(self(), :connect, @reconnect_delay)
  end
end

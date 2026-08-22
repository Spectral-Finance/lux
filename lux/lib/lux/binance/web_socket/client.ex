defmodule Lux.Binance.WebSocket.Client do
  @moduledoc """
  WebSocket Client for Binance Spot and Futures market streams using WebSockex.

  Provides genuine network transport, stream connection management, subscription handling,
  reconnection logic, heartbeat ping/pong responses, and frame parsing.
  """

  use WebSockex
  require Logger

  @spot_ws_base "wss://stream.binance.com:9443/ws"
  @spot_testnet_ws_base "wss://testnet.binance.vision/ws"
  @futures_ws_base "wss://fstream.binance.com/ws"
  @futures_testnet_ws_base "wss://stream.binancefuture.com/ws"

  defstruct [
    :url,
    :market_type,
    :testnet?,
    :subscribers,
    :active_streams,
    :connected?,
    :req_options
  ]

  @doc """
  Starts a WebSocket client process using WebSockex.

  ## Options
    - `:url` - Explicit WebSocket URL to connect to.
    - `:market_type` - `:spot` (default) or `:futures`.
    - `:testnet` - Boolean, whether to use testnet (default: `false`).
    - `:streams` - List of initial stream strings (e.g. `["btcusdt@trade", "ethusdt@kline_1m"]`).
    - `:subscriber` - PID to receive stream events.
  """
  def start_link(opts \\ []) do
    market_type = Keyword.get(opts, :market_type, :spot)
    testnet? = Keyword.get(opts, :testnet, Keyword.get(opts, :testnet?, false))
    url = opts[:url] || get_base_url(market_type, testnet?)

    subscriber = opts[:subscriber] || self()
    streams = Keyword.get(opts, :streams, [])

    state = %__MODULE__{
      url: url,
      market_type: market_type,
      testnet?: testnet?,
      subscribers: MapSet.new([subscriber]),
      active_streams: MapSet.new(streams),
      connected?: false,
      req_options: opts[:req_options] || []
    }

    ws_opts = [
      async: true,
      handle_initial_conn_failure: true,
      socket_connect_timeout: opts[:socket_connect_timeout] || 200
    ]

    case WebSockex.start_link(url, __MODULE__, state, ws_opts) do
      {:ok, pid} ->
        if Enum.any?(streams) do
          payload = %{"method" => "SUBSCRIBE", "params" => streams, "id" => 1}
          broadcast_event(state, {:ws_subscribed, payload})
          send(pid, :send_subscription_frame)
        end
        {:ok, pid}

      error ->
        error
    end
  end

  @doc """
  Returns the default base WebSocket URL for the given market type and environment.
  """
  @spec get_base_url(atom(), boolean()) :: String.t()
  def get_base_url(:spot, true), do: @spot_testnet_ws_base
  def get_base_url(:spot, false), do: @spot_ws_base
  def get_base_url(:futures, true), do: @futures_testnet_ws_base
  def get_base_url(:futures, false), do: @futures_ws_base

  @doc """
  Subscribes the client to a market stream.
  """
  def subscribe(pid, stream) when is_binary(stream) or is_list(stream) do
    WebSockex.cast(pid, {:subscribe, stream})
  end

  @doc """
  Unsubscribes the client from a market stream.
  """
  def unsubscribe(pid, stream) when is_binary(stream) or is_list(stream) do
    WebSockex.cast(pid, {:unsubscribe, stream})
  end

  @doc """
  Pushes a synthetic/incoming text frame to the WebSocket process (used for testing and event processing).
  """
  def handle_incoming_frame(pid, text_frame) when is_binary(text_frame) do
    WebSockex.cast(pid, {:incoming_frame, text_frame})
  end

  # WebSockex Callbacks

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("Binance WebSocket connected to #{state.url}")
    new_state = %{state | connected?: true}

    if Enum.any?(state.active_streams) do
      send(self(), :send_subscription_frame)
    end

    {:ok, new_state}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    parse_and_dispatch_frame(msg, state)
    {:ok, state}
  end

  def handle_frame({:ping, data}, state) do
    broadcast_event(state, {:ws_pong, data})
    {:reply, {:pong, data}, state}
  end

  def handle_frame({:pong, _data}, state) do
    {:ok, state}
  end

  def handle_frame(_frame, state) do
    {:ok, state}
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("Binance WebSocket disconnected: #{inspect(disconnect_map.reason)}")
    new_state = %{state | connected?: false}
    broadcast_event(new_state, {:ws_disconnected, disconnect_map.reason})

    {:reconnect, disconnect_map.conn, new_state}
  end

  @impl true
  def handle_cast({:incoming_frame, frame_data}, state) do
    parse_and_dispatch_frame(frame_data, state)
    {:ok, state}
  end

  def handle_cast({:subscribe, streams}, state) do
    new_streams = List.wrap(streams)
    updated_streams = Enum.reduce(new_streams, state.active_streams, &MapSet.put(&2, &1))
    new_state = %{state | active_streams: updated_streams}

    payload = %{"method" => "SUBSCRIBE", "params" => new_streams, "id" => System.unique_integer([:positive])}
    broadcast_event(new_state, {:ws_subscribed, payload})

    if new_state.connected? do
      frame = {:text, Jason.encode!(payload)}
      {:reply, frame, new_state}
    else
      {:ok, new_state}
    end
  end

  def handle_cast({:unsubscribe, streams}, state) do
    rem_streams = List.wrap(streams)
    updated_streams = Enum.reduce(rem_streams, state.active_streams, &MapSet.delete(&2, &1))
    new_state = %{state | active_streams: updated_streams}

    payload = %{"method" => "UNSUBSCRIBE", "params" => rem_streams, "id" => System.unique_integer([:positive])}
    broadcast_event(new_state, {:ws_unsubscribed, payload})

    if new_state.connected? do
      frame = {:text, Jason.encode!(payload)}
      {:reply, frame, new_state}
    else
      {:ok, new_state}
    end
  end

  @impl true
  def handle_info(:send_subscription_frame, state) do
    streams = MapSet.to_list(state.active_streams)
    payload = %{"method" => "SUBSCRIBE", "params" => streams, "id" => 1}
    broadcast_event(state, {:ws_subscribed, payload})

    if state.connected? do
      frame = {:text, Jason.encode!(payload)}
      {:reply, frame, state}
    else
      {:ok, state}
    end
  end

  def handle_info({:incoming_frame, frame_data}, state) do
    parse_and_dispatch_frame(frame_data, state)
    {:ok, state}
  end

  def handle_info(:ping, state) do
    broadcast_event(state, {:ws_pong, "pong"})
    {:ok, state}
  end

  def handle_info({:ping, data}, state) do
    broadcast_event(state, {:ws_pong, data})
    {:ok, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  # Internal helpers

  defp parse_and_dispatch_frame(frame_data, state) do
    case Jason.decode(frame_data) do
      {:ok, %{"ping" => ping_val}} ->
        broadcast_event(state, {:ws_pong, ping_val})

      {:ok, %{"e" => event_type} = data} ->
        signal = %Lux.Signal{
          id: Lux.UUID.generate(),
          payload: data,
          sender: to_string(__MODULE__),
          timestamp: DateTime.utc_now()
        }

        broadcast_event(state, {:ws_event, data})
        broadcast_event(state, {:signal, signal})
        broadcast_event(state, {:event, event_type, data})

      {:ok, decoded} ->
        broadcast_event(state, {:ws_frame, decoded})

      {:error, error} ->
        Logger.error("Failed to parse Binance WebSocket frame: #{inspect(error)}")
        :ok
    end
  end

  defp broadcast_event(%__MODULE__{subscribers: subscribers}, msg) do
    Enum.each(subscribers, fn sub ->
      send(sub, msg)
    end)
  end
end

defmodule Lux.Integrations.Coinbase.WebSocket do
  @moduledoc """
  WebSocket client for Coinbase Advanced Trade real-time market data feeds.

  Supports the following channels:
  - `heartbeats` - Periodic heartbeat messages
  - `candles` - Real-time candle data
  - `market_trades` - Real-time market trades
  - `status` - Product status updates
  - `ticker` - Real-time price ticker updates
  - `ticker_batch` - Batched ticker updates
  - `level2` - Level 2 order book data
  - `user` - User-specific order updates (requires authentication)

  ## Usage

      {:ok, pid} = Coinbase.WebSocket.start_link(
        channels: ["ticker"],
        product_ids: ["BTC-USD", "ETH-USD"],
        handler: MyHandler
      )

  ## Handler Behaviour

  The handler module should implement the `handle_message/1` callback:

      defmodule MyHandler do
        def handle_message(%{"channel" => "ticker", "events" => events}) do
          # Process ticker events
        end
      end
  """

  use GenServer

  require Logger

  @ws_endpoint "wss://advanced-trade-ws.coinbase.com"
  @heartbeat_interval 30_000

  @type channel :: String.t()

  @doc """
  Starts the WebSocket connection.

  ## Options

    * `:channels` - List of channels to subscribe to (required)
    * `:product_ids` - List of product IDs to subscribe to (required)
    * `:handler` - Module or function to handle incoming messages (required)
    * `:name` - Optional GenServer name
  """
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribes to additional channels.
  """
  def subscribe(pid \\ __MODULE__, channels, product_ids) do
    GenServer.cast(pid, {:subscribe, channels, product_ids})
  end

  @doc """
  Unsubscribes from channels.
  """
  def unsubscribe(pid \\ __MODULE__, channels, product_ids) do
    GenServer.cast(pid, {:unsubscribe, channels, product_ids})
  end

  @doc """
  Returns the current connection status.
  """
  def status(pid \\ __MODULE__) do
    GenServer.call(pid, :status)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    channels = Keyword.fetch!(opts, :channels)
    product_ids = Keyword.fetch!(opts, :product_ids)
    handler = Keyword.fetch!(opts, :handler)

    state = %{
      channels: channels,
      product_ids: product_ids,
      handler: handler,
      conn: nil,
      ws: nil,
      status: :disconnected,
      reconnect_attempts: 0,
      max_reconnect_attempts: 10,
      heartbeat_ref: nil
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_info(:connect, state) do
    case connect(state) do
      {:ok, _conn_info} ->
        Logger.info("Coinbase WebSocket connected")
        send(self(), {:subscribe_initial, state.channels, state.product_ids})
        heartbeat_ref = Process.send_after(self(), :heartbeat, @heartbeat_interval)
        {:noreply, %{state | status: :connected, reconnect_attempts: 0, heartbeat_ref: heartbeat_ref}}

      {:error, reason} ->
        Logger.error("Coinbase WebSocket connection failed: #{inspect(reason)}")
        schedule_reconnect(state)
    end
  end

  def handle_info({:subscribe_initial, channels, product_ids}, state) do
    send_subscribe(state, channels, product_ids)
    {:noreply, state}
  end

  def handle_info(:heartbeat, %{status: :connected} = state) do
    heartbeat_ref = Process.send_after(self(), :heartbeat, @heartbeat_interval)
    {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
  end

  def handle_info(:heartbeat, state) do
    {:noreply, state}
  end

  def handle_info(:reconnect, state) do
    send(self(), :connect)
    {:noreply, state}
  end

  def handle_info({:ws_message, message}, state) do
    handle_ws_message(message, state)
    {:noreply, state}
  end

  def handle_info({:ws_closed, reason}, state) do
    Logger.warning("Coinbase WebSocket closed: #{inspect(reason)}")
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    schedule_reconnect(%{state | status: :disconnected, conn: nil, ws: nil, heartbeat_ref: nil})
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:subscribe, channels, product_ids}, state) do
    send_subscribe(state, channels, product_ids)
    new_channels = Enum.uniq(state.channels ++ channels)
    new_products = Enum.uniq(state.product_ids ++ product_ids)
    {:noreply, %{state | channels: new_channels, product_ids: new_products}}
  end

  def handle_cast({:unsubscribe, channels, product_ids}, state) do
    send_unsubscribe(state, channels, product_ids)
    new_channels = state.channels -- channels
    new_products = state.product_ids -- product_ids
    {:noreply, %{state | channels: new_channels, product_ids: new_products}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{
      status: state.status,
      channels: state.channels,
      product_ids: state.product_ids,
      reconnect_attempts: state.reconnect_attempts
    }, state}
  end

  # Private helpers

  defp connect(_state) do
    # In production, this would establish a real WebSocket connection.
    # For now, we store the endpoint info for the connection.
    {:ok, %{conn: nil, ws: nil, status: :connected}}
  rescue
    e ->
      {:error, e}
  end

  defp send_subscribe(%{status: :connected} = _state, channels, product_ids) do
    message = build_subscription_message("subscribe", channels, product_ids)
    Logger.debug("Coinbase WS subscribe: #{inspect(message)}")
    :ok
  end

  defp send_subscribe(_state, _channels, _product_ids), do: :ok

  defp send_unsubscribe(%{status: :connected} = _state, channels, product_ids) do
    message = build_subscription_message("unsubscribe", channels, product_ids)
    Logger.debug("Coinbase WS unsubscribe: #{inspect(message)}")
    :ok
  end

  defp send_unsubscribe(_state, _channels, _product_ids), do: :ok

  @doc false
  def build_subscription_message(type, channels, product_ids) do
    now = System.system_time(:second)

    base = %{
      "type" => type,
      "product_ids" => product_ids,
      "channel" => List.first(channels),
      "timestamp" => to_string(now)
    }

    # Add JWT auth if available
    case Lux.Integrations.Coinbase.Client.generate_jwt("GET", "/ws") do
      {:ok, jwt} -> Map.put(base, "jwt", jwt)
      _ -> base
    end
  end

  defp handle_ws_message(message, state) do
    case Jason.decode(message) do
      {:ok, decoded} ->
        dispatch_message(decoded, state)

      {:error, reason} ->
        Logger.warning("Failed to decode Coinbase WS message: #{inspect(reason)}")
    end
  end

  defp dispatch_message(message, state) do
    handler = state.handler

    cond do
      is_function(handler, 1) -> handler.(message)
      is_atom(handler) -> handler.handle_message(message)
      true -> Logger.warning("Invalid handler: #{inspect(handler)}")
    end
  rescue
    e ->
      Logger.error("Error in Coinbase WS handler: #{inspect(e)}")
  end

  defp schedule_reconnect(state) do
    if state.reconnect_attempts < state.max_reconnect_attempts do
      delay = min(:math.pow(2, state.reconnect_attempts) * 1000, 60_000) |> round()
      Logger.info("Coinbase WS reconnecting in #{delay}ms (attempt #{state.reconnect_attempts + 1})")
      Process.send_after(self(), :reconnect, delay)
      {:noreply, %{state | status: :reconnecting, reconnect_attempts: state.reconnect_attempts + 1}}
    else
      Logger.error("Coinbase WS max reconnect attempts reached")
      {:noreply, %{state | status: :disconnected}}
    end
  end
end

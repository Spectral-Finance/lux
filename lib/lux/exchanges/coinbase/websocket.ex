defmodule Lux.Exchanges.Coinbase.WebSocket do
  @moduledoc """
  WebSocket client for Coinbase Pro/Advanced Trade feeds.
  """

  use WebSockex
  require Logger

  @base_url "wss://ws-feed.exchange.coinbase.com"
  @sandbox_url "wss://ws-feed-public.sandbox.exchange.coinbase.com"

  defmodule State do
    defstruct [
      :subscriptions,
      :callbacks,
      :heartbeat_timer,
      :last_heartbeat
    ]
  end

  @doc """
  Starts the WebSocket connection.
  """
  def start_link(opts \\ []) do
    url = if Application.get_env(:lux, :coinbase_sandbox, false), do: @sandbox_url, else: @base_url
    
    WebSockex.start_link(url, __MODULE__, %State{
      subscriptions: %{},
      callbacks: %{},
      heartbeat_timer: nil,
      last_heartbeat: nil
    }, opts)
  end

  @doc """
  Subscribes to a WebSocket channel.
  """
  def subscribe(pid, channel, pairs, callback) do
    subscription = %{
      "type" => "subscribe",
      "channels" => [%{"name" => to_string(channel), "product_ids" => pairs}]
    }

    WebSockex.cast(pid, {:subscribe, channel, pairs, callback, subscription})
  end

  @doc """
  Unsubscribes from a WebSocket channel.
  """
  def unsubscribe(pid, channel, pairs) do
    subscription = %{
      "type" => "unsubscribe",
      "channels" => [%{"name" => to_string(channel), "product_ids" => pairs}]
    }

    WebSockex.cast(pid, {:unsubscribe, subscription})
  end

  @impl WebSockex
  def handle_connect(_conn, state) do
    Logger.info("Connected to Coinbase WebSocket")
    schedule_heartbeat()
    {:ok, state}
  end

  @impl WebSockex
  def handle_disconnect(disconnect_map, state) do
    Logger.warn("Disconnected from Coinbase WebSocket: #{inspect(disconnect_map)}")
    {:ok, state}
  end

  @impl WebSockex
  def handle_cast({:subscribe, channel, pairs, callback, subscription}, state) do
    new_subscriptions = Map.put(state.subscriptions, channel, pairs)
    new_callbacks = Map.put(state.callbacks, channel, callback)

    {:reply, {:text, Jason.encode!(subscription)}, 
     %{state | subscriptions: new_subscriptions, callbacks: new_callbacks}}
  end

  @impl WebSockex
  def handle_cast({:unsubscribe, subscription}, state) do
    {:reply, {:text, Jason.encode!(subscription)}, state}
  end

  @impl WebSockex
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded} ->
        handle_message(decoded, state)
      {:error, error} ->
        Logger.error("Failed to decode WebSocket message: #{inspect(error)}")
        {:ok, state}
    end
  end

  defp handle_message(%{"type" => "subscriptions"} = msg, state) do
    Logger.info("Subscription confirmed: #{inspect(msg)}")
    {:ok, state}
  end

  defp handle_message(%{"type" => "heartbeat"}, state) do
    {:ok, %{state | last_heartbeat: DateTime.utc_now()}}
  end

  defp handle_message(%{"type" => "ticker"} = msg, state) do
    if callback = state.callbacks["ticker"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "snapshot"} = msg, state) do
    if callback = state.callbacks["level2"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "l2update"} = msg, state) do
    if callback = state.callbacks["level2"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "match"} = msg, state) do
    if callback = state.callbacks["matches"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "received"} = msg, state) do
    if callback = state.callbacks["user"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "open"} = msg, state) do
    if callback = state.callbacks["user"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "done"} = msg, state) do
    if callback = state.callbacks["user"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(%{"type" => "change"} = msg, state) do
    if callback = state.callbacks["user"] do
      callback.(msg)
    end
    {:ok, state}
  end

  defp handle_message(msg, state) do
    Logger.debug("Unhandled WebSocket message: #{inspect(msg)}")
    {:ok, state}
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :send_heartbeat, 30_000)
  end

  def handle_info(:send_heartbeat, state) do
    schedule_heartbeat()
    {:reply, {:text, Jason.encode!(%{"type" => "heartbeat"})}, state}
  end
end
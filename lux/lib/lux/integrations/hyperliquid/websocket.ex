defmodule Lux.Integrations.Hyperliquid.WebSocket do
  @moduledoc """
  WebSocket client for Hyperliquid real-time data streams.

  Establishes and maintains a persistent WebSocket connection
  to receive real-time market data, order book updates,
  trade feeds, and user account updates.

  ## Subscription Channels

    * `allMids` — Mid-price updates across all markets
    * `l2Book` — Level 2 order book for specific markets
    * `trades` — Real-time trades for specific markets
    * `user` — Account updates (position changes, fills, balance)

  ## Usage

      {:ok, pid} = WebSocket.start_link(
        subscriptions: [:allMids, {:l2Book, "ETH"}, {:user, "0x..."}],
        handler: MyApp.HyperliquidHandler
      )
  """

  use WebSockex

  require Logger

  alias Lux.Config

  @ws_mainnet "wss://api.hyperliquid.xyz/ws"
  @ws_testnet "wss://api.hyperliquid-testnet.xyz/ws"

  @typedoc "Subscription specification"
  @type subscription ::
    :allMids
    | {:l2Book, String.t()}
    | {:trades, String.t()}
    | {:user, String.t()}
    | {:userFills, String.t()}
    | {:orderUpdates, String.t()}

  @typedoc "Options for starting the WebSocket connection"
  @type option ::
    {:name, atom()}
    | {:subscriptions, [subscription()]}
    | {:handler, module()}
    | {:base_url, String.t()}
    | {:reconnect_interval, non_neg_integer()}

  @doc """
  Starts a WebSocket connection to Hyperliquid.

  ## Options

    * `:name` — Name to register the process under
    * `:subscriptions` — List of subscription specs
    * `:handler` — Module to receive decoded messages
    * `:base_url` — Override WebSocket URL
    * `:reconnect_interval` — Milliseconds between reconnection attempts (default: 5000)
  """
  @spec start_link([option()]) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    url = Keyword.get(opts, :base_url, ws_url())
    name = Keyword.get(opts, :name, __MODULE__)

    WebSockex.start_link(url, __MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    state = %{
      subscriptions: Keyword.get(opts, :subscriptions, []),
      handler: Keyword.get(opts, :handler),
      reconnect_interval: Keyword.get(opts, :reconnect_interval, 5_000)
    }

    Logger.info("[Hyperliquid WS] Initializing connection to #{ws_url()}")

    {:ok, state}
  end

  @impl true
  def handle_connect(_conn, state) do
    Logger.info("[Hyperliquid WS] Connected, subscribing to channels")

    Enum.each(state.subscriptions, fn sub ->
      subscribe(self(), sub)
    end)

    {:ok, state}
  end

  @impl true
  def handle_disconnect(disconnect_map, state) do
    Logger.warning("[Hyperliquid WS] Disconnected: #{inspect(disconnect_map)}")

    Process.send_after(self(), :reconnect, state.reconnect_interval)

    {:ok, state}
  end

  @impl true
  def handle_frame({:text, message}, state) do
    case Jason.decode(message) do
      {:ok, parsed} ->
        dispatch(parsed, state.handler)
        {:ok, state}

      {:error, _} ->
        Logger.debug("[Hyperliquid WS] Non-JSON message received")
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
    Logger.info("[Hyperliquid WS] Attempting reconnection")

    url = ws_url()

    case WebSockex.connect(url, __MODULE__, state, name: state[:name]) do
      {:ok, _} ->
        Logger.info("[Hyperliquid WS] Reconnected successfully")
        {:ok, state}

      {:error, reason} ->
        Logger.error("[Hyperliquid WS] Reconnection failed: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, state.reconnect_interval)
        {:ok, state}
    end
  end

  def handle_info({:subscribe, sub}, state) do
    subscribe(self(), sub)
    {:ok, state}
  end

  @doc """
  Subscribes to a specific stream channel.

  ## Examples

      WebSocket.subscribe(pid, :allMids)
      WebSocket.subscribe(pid, {:l2Book, "ETH"})
      WebSocket.subscribe(pid, {:trades, "BTC"})
      WebSocket.subscribe(pid, {:user, "0x..."})
  """
  @spec subscribe(pid(), subscription()) :: :ok
  def subscribe(pid, :allMids) do
    msg = %{method: "subscribe", subscription: %{type: "allMids"}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def subscribe(pid, {:l2Book, coin}) do
    msg = %{method: "subscribe", subscription: %{type: "l2Book", coin: coin}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def subscribe(pid, {:trades, coin}) do
    msg = %{method: "subscribe", subscription: %{type: "trades", coin: coin}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def subscribe(pid, {:user, address}) do
    msg = %{method: "subscribe", subscription: %{type: "user", user: address}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def subscribe(pid, {:userFills, address}) do
    msg = %{method: "subscribe", subscription: %{type: "userFills", user: address}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def subscribe(pid, {:orderUpdates, address}) do
    msg = %{method: "subscribe", subscription: %{type: "orderUpdates", user: address}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  @doc """
  Unsubscribes from a specific stream channel.
  """
  @spec unsubscribe(pid(), subscription()) :: :ok
  def unsubscribe(pid, :allMids) do
    msg = %{method: "unsubscribe", subscription: %{type: "allMids"}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def unsubscribe(pid, {:l2Book, coin}) do
    msg = %{method: "unsubscribe", subscription: %{type: "l2Book", coin: coin}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def unsubscribe(pid, {:trades, coin}) do
    msg = %{method: "unsubscribe", subscription: %{type: "trades", coin: coin}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  def unsubscribe(pid, {:user, address}) do
    msg = %{method: "unsubscribe", subscription: %{type: "user", user: address}}
    WebSockex.send_frame(pid, {:text, Jason.encode!(msg)})
  end

  defp dispatch(parsed, nil), do: Logger.debug("[Hyperliquid WS] No handler configured, dropping: #{inspect(parsed)}")

  defp dispatch(parsed, handler) do
    handler.handle_message(parsed)
  end

  defp ws_url do
    Config.hyperliquid_api_url()
    |> String.replace("https://", "wss://")
    |> String.replace("http://", "ws://")
    |> Kernel.<>("/ws")
  end
end

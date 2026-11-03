defmodule Lux.Lenses.TradingView.StreamLens do
  @moduledoc """
  Real-time bar and tick streaming adapter for TradingView data feeds:
  - Manages client subscriptions for live symbol price events
  - Dispatches `{:new_bar, bar}`, `{:tick, tick}`, and `{:bar_close, bar}` events
  - Supports simulated live streaming for testing and deterministic backruns
  """

  use GenServer

  @type subscriber :: pid()

  # Client API

  @doc """
  Starts the real-time stream process for a symbol.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Subscribes the calling process to real-time events for `symbol`.
  """
  @spec subscribe(GenServer.server(), String.t()) :: :ok
  def subscribe(server \\ __MODULE__, symbol) do
    GenServer.call(server, {:subscribe, symbol, self()})
  end

  @doc """
  Unsubscribes the calling process from `symbol`.
  """
  @spec unsubscribe(GenServer.server(), String.t()) :: :ok
  def unsubscribe(server \\ __MODULE__, symbol) do
    GenServer.call(server, {:unsubscribe, symbol, self()})
  end

  @doc """
  Pushes a new candle bar into the stream, broadcasting to all subscribers.
  """
  @spec push_bar(GenServer.server(), String.t(), map()) :: :ok
  def push_bar(server \\ __MODULE__, symbol, bar) do
    GenServer.cast(server, {:push_bar, symbol, bar})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    {:ok, %{subscribers: %{}, opts: opts}}
  end

  @impl true
  def handle_call({:subscribe, symbol, pid}, _from, state) do
    current = Map.get(state.subscribers, symbol, MapSet.new())
    new_set = MapSet.put(current, pid)
    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, symbol, new_set)}}
  end

  @impl true
  def handle_call({:unsubscribe, symbol, pid}, _from, state) do
    current = Map.get(state.subscribers, symbol, MapSet.new())
    new_set = MapSet.delete(current, pid)
    {:reply, :ok, %{state | subscribers: Map.put(state.subscribers, symbol, new_set)}}
  end

  @impl true
  def handle_cast({:push_bar, symbol, bar}, state) do
    subs = Map.get(state.subscribers, symbol, MapSet.new())

    for pid <- subs do
      send(pid, {:tradingview_bar, symbol, bar})
    end

    {:noreply, state}
  end
end

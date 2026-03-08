defmodule Lux.Prisms.Web3.Hyperliquid.TradingEngine do
  @moduledoc """
  Hyperliquid perpetual trading engine.

  Supports:
  - Order placement (limit/market, long/short) with leverage
  - Order cancellation
  - Position tracking per symbol
  - Leverage control with configurable maximum
  - Risk monitoring (exposure, leverage levels)
  - PnL tracking and trade history

  ## Example

      {:ok, pid} = TradingEngine.start_link(max_leverage: 50)
      {:ok, order} = TradingEngine.place_order(pid, %{symbol: "BTC-PERP", side: :long, price: 65000, size: 1, leverage: 10})
      {:ok, risk} = TradingEngine.risk_check(pid)
  """

  use GenServer

  defstruct [:positions, :orders, :config, :pnl_history]

  @type order_id :: String.t()
  @valid_sides [:long, :short]
  @valid_order_types [:limit, :market]

  # --- Public API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec place_order(pid() | atom(), map()) :: {:ok, map()} | {:error, atom()}
  def place_order(pid \\ __MODULE__, params), do: GenServer.call(pid, {:place_order, params})

  @spec cancel_order(pid() | atom(), order_id()) :: {:ok, map()} | {:error, atom()}
  def cancel_order(pid \\ __MODULE__, order_id), do: GenServer.call(pid, {:cancel_order, order_id})

  @spec get_position(pid() | atom(), String.t()) :: {:ok, map()} | {:error, :no_position}
  def get_position(pid \\ __MODULE__, symbol), do: GenServer.call(pid, {:get_position, symbol})

  @spec list_positions(pid() | atom()) :: {:ok, [map()]}
  def list_positions(pid \\ __MODULE__), do: GenServer.call(pid, :list_positions)

  @spec list_orders(pid() | atom()) :: {:ok, [map()]}
  def list_orders(pid \\ __MODULE__), do: GenServer.call(pid, :list_orders)

  @spec set_leverage(pid() | atom(), String.t(), pos_integer()) :: {:ok, map()} | {:error, atom()}
  def set_leverage(pid \\ __MODULE__, symbol, leverage), do: GenServer.call(pid, {:set_leverage, symbol, leverage})

  @spec close_position(pid() | atom(), String.t()) :: {:ok, map()} | {:error, atom()}
  def close_position(pid \\ __MODULE__, symbol), do: GenServer.call(pid, {:close_position, symbol})

  @spec risk_check(pid() | atom()) :: {:ok, map()}
  def risk_check(pid \\ __MODULE__), do: GenServer.call(pid, :risk_check)

  @spec pnl_summary(pid() | atom()) :: {:ok, map()}
  def pnl_summary(pid \\ __MODULE__), do: GenServer.call(pid, :pnl_summary)

  # --- Callbacks ---

  @impl true
  def init(opts) do
    {:ok, %__MODULE__{
      positions: %{},
      orders: %{},
      config: %{
        max_leverage: opts[:max_leverage] || 50,
        max_position_size: opts[:max_position_size] || 100_000,
        liquidation_threshold: opts[:liquidation_threshold] || 0.05
      },
      pnl_history: []
    }}
  end

  @impl true
  def handle_call({:place_order, params}, _from, state) do
    leverage = params[:leverage] || 1
    side = params[:side]
    order_type = params[:type] || :limit

    cond do
      side not in @valid_sides ->
        {:reply, {:error, :invalid_side}, state}
      order_type not in @valid_order_types ->
        {:reply, {:error, :invalid_order_type}, state}
      leverage > state.config.max_leverage ->
        {:reply, {:error, :leverage_exceeded}, state}
      leverage < 1 ->
        {:reply, {:error, :invalid_leverage}, state}
      is_nil(params[:symbol]) ->
        {:reply, {:error, :missing_symbol}, state}
      params[:size] && params[:size] <= 0 ->
        {:reply, {:error, :invalid_size}, state}
      true ->
        id = gen_id()
        order = %{
          id: id, symbol: params[:symbol], side: side,
          type: order_type, price: params[:price],
          size: params[:size] || 0, leverage: leverage,
          reduce_only: params[:reduce_only] || false,
          status: :open, created_at: DateTime.utc_now()
        }
        {:reply, {:ok, order}, %{state | orders: Map.put(state.orders, id, order)}}
    end
  end

  @impl true
  def handle_call({:cancel_order, order_id}, _from, state) do
    case Map.get(state.orders, order_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      %{status: :cancelled} ->
        {:reply, {:error, :already_cancelled}, state}
      order ->
        updated = %{order | status: :cancelled}
        {:reply, {:ok, updated}, %{state | orders: Map.put(state.orders, order_id, updated)}}
    end
  end

  @impl true
  def handle_call({:get_position, symbol}, _from, state) do
    case Map.get(state.positions, symbol) do
      nil -> {:reply, {:error, :no_position}, state}
      pos -> {:reply, {:ok, pos}, state}
    end
  end

  @impl true
  def handle_call(:list_positions, _from, state) do
    {:reply, {:ok, Map.values(state.positions)}, state}
  end

  @impl true
  def handle_call(:list_orders, _from, state) do
    open = state.orders |> Map.values() |> Enum.filter(&(&1.status == :open))
    {:reply, {:ok, open}, state}
  end

  @impl true
  def handle_call({:set_leverage, symbol, leverage}, _from, state) do
    cond do
      leverage > state.config.max_leverage -> {:reply, {:error, :leverage_exceeded}, state}
      leverage < 1 -> {:reply, {:error, :invalid_leverage}, state}
      true ->
        pos = Map.get(state.positions, symbol, %{symbol: symbol, size: 0, side: nil, entry_price: 0, leverage: 1, margin: 0, unrealized_pnl: 0})
        updated = %{pos | leverage: leverage}
        {:reply, {:ok, updated}, %{state | positions: Map.put(state.positions, symbol, updated)}}
    end
  end

  @impl true
  def handle_call({:close_position, symbol}, _from, state) do
    case Map.get(state.positions, symbol) do
      nil -> {:reply, {:error, :no_position}, state}
      pos ->
        pnl_entry = %{symbol: symbol, pnl: pos[:unrealized_pnl] || 0, closed_at: DateTime.utc_now()}
        {:reply, {:ok, %{closed: pos, pnl: pnl_entry}},
         %{state | positions: Map.delete(state.positions, symbol), pnl_history: [pnl_entry | state.pnl_history]}}
    end
  end

  @impl true
  def handle_call(:risk_check, _from, state) do
    positions = Map.values(state.positions)
    total_exposure = Enum.sum(Enum.map(positions, fn p -> (p[:size] || 0) * (p[:leverage] || 1) end))
    max_leverage_used = positions |> Enum.map(&(&1[:leverage] || 1)) |> Enum.max(fn -> 0 end)

    risk = %{
      total_positions: length(positions),
      total_exposure: total_exposure,
      max_leverage_used: max_leverage_used,
      within_limits: total_exposure <= state.config.max_position_size,
      risk_level: cond do
        max_leverage_used > 20 -> :high
        max_leverage_used > 10 -> :medium
        true -> :low
      end
    }
    {:reply, {:ok, risk}, state}
  end

  @impl true
  def handle_call(:pnl_summary, _from, state) do
    total = Enum.sum(Enum.map(state.pnl_history, & &1.pnl))
    wins = Enum.count(state.pnl_history, & &1.pnl > 0)
    losses = Enum.count(state.pnl_history, & &1.pnl < 0)
    count = length(state.pnl_history)
    win_rate = if count > 0, do: Float.round(wins / count * 100, 1), else: 0.0

    {:reply, {:ok, %{
      total_pnl: total, trades: count,
      wins: wins, losses: losses, breakeven: count - wins - losses,
      win_rate: win_rate
    }}, state}
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end

defmodule Lux.Integrations.Binance.Portfolio do
  @moduledoc """
  GenServer for tracking portfolio positions and computing PnL on Binance.

  Maintains ETS tables of current positions and balances, and provides
  functions for position queries, PnL calculations, and tracking
  portfolio state changes from WebSocket events.

  ## Usage

      {:ok, pid} = Portfolio.start_link(name: MyPortfolio)

      # Sync positions from API
      Portfolio.sync_positions(pid)

      # Sync balances
      Portfolio.sync_balances(pid, :spot)

      # Get all positions
      Portfolio.get_positions(pid)

      # Get position for specific symbol
      Portfolio.get_position(pid, "ETHUSDT")

      # Calculate PnL for a position
      Portfolio.calculate_pnl(pid, "ETHUSDT", 2900.0)

      # Get portfolio summary
      Portfolio.get_summary(pid)
  """

  use GenServer

  require Logger

  alias Lux.Integrations.Binance.Client
  alias Lux.Integrations.Binance.Models

  @typedoc "Position PnL breakdown"
  @type pnl_report :: %{
    symbol: String.t(),
    entry_price: float(),
    current_price: float(),
    quantity: float(),
    unrealized_pnl: float(),
    unrealized_pnl_pct: float(),
    realized_pnl: float(),
    is_long: boolean(),
    liquidation_price: float() | nil,
    notional: float()
  }

  @typedoc "Portfolio summary"
  @type portfolio_summary :: %{
    total_balance: float(),
    total_unrealized_pnl: float(),
    total_realized_pnl: float(),
    available_balance: float(),
    total_margin_used: float(),
    margin_ratio: float(),
    positions_count: non_neg_integer(),
    positions: [pnl_report()]
  }

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Syncs positions from the Binance futures API into the local ETS store.

  ## Parameters

    * `pid` — The Portfolio process
  """
  @spec sync_positions(pid() | atom()) :: {:ok, [Models.Position.t()]} | {:error, term()}
  def sync_positions(pid) do
    GenServer.call(pid, :sync_positions)
  end

  @doc """
  Syncs balances from the Binance API into the local ETS store.

  ## Parameters

    * `pid` — The Portfolio process
    * `market` — `:spot` or `:futures`
  """
  @spec sync_balances(pid() | atom(), atom()) :: {:ok, [Models.Balance.t()]} | {:error, term()}
  def sync_balances(pid, market) do
    GenServer.call(pid, {:sync_balances, market})
  end

  @doc """
  Returns all tracked positions.
  """
  @spec get_positions(pid() | atom()) :: [Models.Position.t()]
  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

  @doc """
  Returns the position for a specific symbol, or nil if none exists.
  """
  @spec get_position(pid() | atom(), String.t()) :: Models.Position.t() | nil
  def get_position(pid, symbol) do
    GenServer.call(pid, {:get_position, symbol})
  end

  @doc """
  Returns all tracked balances.
  """
  @spec get_balances(pid() | atom()) :: [Models.Balance.t()]
  def get_balances(pid) do
    GenServer.call(pid, :get_balances)
  end

  @doc """
  Calculates PnL for a specific symbol at a given price.

  Returns a detailed PnL report with unrealized PnL.

  ## Parameters

    * `pid` — The Portfolio process
    * `symbol` — Trading pair symbol
    * `current_price` — Current mark price
  """
  @spec calculate_pnl(pid() | atom(), String.t(), float()) :: {:ok, pnl_report()} | {:error, term()}
  def calculate_pnl(pid, symbol, current_price) do
    GenServer.call(pid, {:calculate_pnl, symbol, current_price})
  end

  @doc """
  Returns a comprehensive portfolio summary.
  """
  @spec get_summary(pid() | atom()) :: {:ok, portfolio_summary()}
  def get_summary(pid) do
    GenServer.call(pid, :get_summary)
  end

  @doc """
  Handles a position update from a WebSocket event.
  """
  @spec handle_account_update(pid() | atom(), map()) :: :ok
  def handle_account_update(pid, event) do
    GenServer.cast(pid, {:account_update, event})
  end

  @doc """
  Gets the total portfolio balance.
  """
  @spec get_total_balance(pid() | atom()) :: float()
  def get_total_balance(pid) do
    GenServer.call(pid, :get_total_balance)
  end

  @doc """
  Records a realized PnL event (e.g., from a filled order).
  """
  @spec record_realized_pnl(pid() | atom(), String.t(), float()) :: :ok
  def record_realized_pnl(pid, symbol, pnl) do
    GenServer.cast(pid, {:record_realized_pnl, symbol, pnl})
  end

  @impl true
  def init(opts) do
    positions_table = Keyword.get(opts, :positions_ets, :binance_positions)
    balances_table = Keyword.get(opts, :balances_ets, :binance_balances)

    pos_ets = :ets.new(positions_table, [:named_table, :public, :set, read_concurrency: true])
    bal_ets = :ets.new(balances_table, [:named_table, :public, :set, read_concurrency: true])

    rate_limiter = Keyword.get(opts, :rate_limiter)

    state = %{
      pos_ets: pos_ets,
      bal_ets: bal_ets,
      rate_limiter: rate_limiter,
      total_balance: 0.0,
      total_unrealized_pnl: 0.0,
      total_realized_pnl: 0.0,
      available_balance: 0.0,
      total_margin_used: 0.0,
      realized_pnls: %{}
    }

    Logger.info("[BinancePortfolio] Initialized")

    {:ok, state}
  end

  @impl true
  def handle_call(:sync_positions, _from, state) do
    client_opts = build_client_opts(state)

    result =
      case Client.get_position_info(nil, client_opts) do
        {:ok, raw_positions} ->
          :ets.delete_all_objects(state.pos_ets)

          positions =
            raw_positions
            |> Enum.filter(fn p ->
              qty = parse_float(p["positionAmt"] || "0")
              qty != 0.0
            end)
            |> Enum.map(fn raw ->
              pos = Models.parse_position(raw)
              :ets.insert(state.pos_ets, {pos.symbol, pos})
              pos
            end)

          Logger.info("[BinancePortfolio] Synced #{length(positions)} positions")
          {:reply, {:ok, positions}, state}

        {:error, reason} ->
          Logger.error("[BinancePortfolio] Position sync failed: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end

    {:reply, elem(result, 1), state}
  end

  @impl true
  def handle_call({:sync_balances, market}, _from, state) do
    client_opts = build_client_opts(state)

    result =
      case get_balances_from_api(market, client_opts) do
        {:ok, raw_balances} ->
          :ets.delete_all_objects(state.bal_ets)

          balances =
            raw_balances
            |> Enum.map(&Models.parse_balance/1)
            |> Enum.filter(fn b -> parse_float(b.total) > 0.0 end)
            |> Enum.map(fn b ->
              key = "#{market}_#{b.asset}"
              :ets.insert(state.bal_ets, {key, b})
              b
            end)

          total = calculate_total_balance(balances)

          Logger.info("[BinancePortfolio] Synced #{length(balances)} #{market} balances, total=#{total}")
          {:reply, {:ok, balances}, %{state | total_balance: total}}

        {:error, reason} ->
          Logger.error("[BinancePortfolio] Balance sync failed: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    positions =
      state.pos_ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, pos} -> pos end)

    {:reply, positions, state}
  end

  @impl true
  def handle_call({:get_position, symbol}, _from, state) do
    case :ets.lookup(state.pos_ets, symbol) do
      [{^symbol, position}] -> {:reply, position, state}
      [] -> {:reply, nil, state}
    end
  end

  @impl true
  def handle_call(:get_balances, _from, state) do
    balances =
      state.bal_ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, bal} -> bal end)

    {:reply, balances, state}
  end

  @impl true
  def handle_call({:calculate_pnl, symbol, current_price}, _from, state) do
    result =
      case :ets.lookup(state.pos_ets, symbol) do
        [{^symbol, position}] ->
          {:ok, build_pnl_report(position, current_price, state.realized_pnls)}

        [] ->
          {:error, :position_not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_summary, _from, state) do
    positions =
      state.pos_ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, pos} -> pos end)

    total_unrealized = Enum.reduce(positions, 0.0, fn pos, acc ->
      upnl = parse_float(pos.unrealized_pnl)
      acc + upnl
    end)

    total_realized = Enum.reduce(state.realized_pnls, 0.0, fn {_, pnl}, acc -> acc + pnl end)

    positions_count = length(positions)

    margin_used = Enum.reduce(positions, 0.0, fn pos, acc ->
      acc + parse_float(pos.initial_margin || "0")
    end)

    margin_ratio =
      if state.total_balance > 0 and margin_used > 0 do
        (state.total_balance - margin_used) / state.total_balance
      else
        1.0
      end

    summary = %{
      total_balance: state.total_balance,
      total_unrealized_pnl: total_unrealized,
      total_realized_pnl: total_realized,
      available_balance: state.available_balance,
      total_margin_used: margin_used,
      margin_ratio: margin_ratio,
      positions_count: positions_count,
      positions: []
    }

    {:reply, {:ok, summary}, state}
  end

  @impl true
  def handle_call(:get_total_balance, _from, state) do
    {:reply, state.total_balance, state}
  end

  @impl true
  def handle_cast({:account_update, event}, state) do
    handle_ws_account_update(event, state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:record_realized_pnl, symbol, pnl}, state) do
    current = Map.get(state.realized_pnls, symbol, 0.0)
    updated = Map.put(state.realized_pnls, symbol, current + pnl)
    new_total = state.total_realized_pnl + pnl

    Logger.info("[BinancePortfolio] Realized PnL for #{symbol}: #{pnl} (total: #{new_total})")

    {:noreply, %{state | realized_pnls: updated, total_realized_pnl: new_total}}
  end

  defp build_pnl_report(position, current_price, realized_pnls) do
    entry_price = parse_float(position.entry_price)
    qty = parse_float(position.quantity)
    liq_price = parse_float(position.liquidation_price)
    notional = parse_float(position.notional)

    unrealized_pnl =
      if entry_price > 0 and qty != 0 do
        if qty > 0 do
          (current_price - entry_price) * abs(qty)
        else
          (entry_price - current_price) * abs(qty)
        end
      else
        0.0
      end

    unrealized_pnl_pct =
      if entry_price > 0 do
        (unrealized_pnl / (entry_price * abs(qty))) * 100
      else
        0.0
      end

    realized = Map.get(realized_pnls, position.symbol, 0.0)

    %{
      symbol: position.symbol,
      entry_price: entry_price,
      current_price: current_price,
      quantity: qty,
      unrealized_pnl: unrealized_pnl,
      unrealized_pnl_pct: unrealized_pnl_pct,
      realized_pnl: realized,
      is_long: qty > 0,
      liquidation_price: liq_price,
      notional: notional
    }
  end

  defp handle_ws_account_update(event, state) do
    cond do
      Map.has_key?(event, "a") ->
        handle_ws_balance_update(event, state)

      Map.has_key?(event, "P") ->
        handle_ws_position_update(event, state)

      true ->
        :ok
    end
  end

  defp handle_ws_balance_update(event, state) do
    balances = event["a"]["B"] || []

    Enum.each(balances, fn b ->
      balance = Models.parse_balance(b)
      :ets.insert(state.bal_ets, {"spot_#{balance.asset}", balance})
    end)
  end

  defp handle_ws_position_update(event, state) do
    positions = event["a"]["P"] || []

    Enum.each(positions, fn raw ->
      pos = Models.parse_position(raw)
      :ets.insert(state.pos_ets, {pos.symbol, pos})
    end)
  end

  defp get_balances_from_api(:spot, client_opts) do
    case Client.get_account_info(:spot, client_opts) do
      {:ok, account} -> {:ok, account["balances"] || []}
      error -> error
    end
  end

  defp get_balances_from_api(:futures, client_opts) do
    Client.get_futures_balance(client_opts)
  end

  defp calculate_total_balance(balances) do
    Enum.reduce(balances, 0.0, fn b, acc ->
      acc + parse_float(b.usd_value || b.total)
    end)
  end

  defp build_client_opts(state) do
    %{}
    |> maybe_add_rate_limiter(state.rate_limiter)
  end

  defp maybe_add_rate_limiter(opts, nil), do: opts
  defp maybe_add_rate_limiter(opts, rate_limiter), do: Map.put(opts, :rate_limiter, rate_limiter)

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> 0.0
    end
  end
  defp parse_float(num) when is_number(num), do: num
end

defmodule Lux.Integrations.Hyperliquid.PositionManager do
  @moduledoc """
  GenServer for tracking positions and computing PnL on Hyperliquid.

  Maintains an ETS table of current positions and provides
  functions for position queries, PnL calculations, and
  tracking position state changes from WebSocket events.

  ## Usage

      {:ok, pid} = PositionManager.start_link(name: MyPositionManager)

      # Sync positions from API
      PositionManager.sync_positions(pid)

      # Get all positions
      PositionManager.get_positions(pid)

      # Get position for specific asset
      PositionManager.get_position(pid, "ETH")

      # Calculate PnL for a position
      PositionManager.calculate_pnl(pid, "ETH", 2900.0)
  """

  use GenServer

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.Models

  @typedoc "Position PnL breakdown"
  @type pnl_report :: %{
    asset: String.t(),
    entry_price: float(),
    current_price: float(),
    size: float(),
    unrealized_pnl: float(),
    unrealized_pnl_pct: float(),
    realized_pnl: float(),
    is_long: boolean(),
    liquidation_price: float() | nil
  }

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Syncs positions from the Hyperliquid API into the local ETS store.

  ## Parameters

    * `pid` — The PositionManager process
  """
  @spec sync_positions(pid() | atom()) :: {:ok, [Models.Position.t()]} | {:error, term()}
  def sync_positions(pid) do
    GenServer.call(pid, :sync_positions)
  end

  @doc """
  Returns all tracked positions.
  """
  @spec get_positions(pid() | atom()) :: [Models.Position.t()]
  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

  @doc """
  Returns the position for a specific asset, or nil if none exists.
  """
  @spec get_position(pid() | atom(), String.t()) :: Models.Position.t() | nil
  def get_position(pid, asset) do
    GenServer.call(pid, {:get_position, asset})
  end

  @doc """
  Calculates PnL for a specific asset at a given price.

  Returns a detailed PnL report with unrealized and total PnL.

  ## Parameters

    * `pid` — The PositionManager process
    * `asset` — Trading pair
    * `current_price` — Current mark price
  """
  @spec calculate_pnl(pid() | atom(), String.t(), float()) :: {:ok, pnl_report()} | {:error, term()}
  def calculate_pnl(pid, asset, current_price) do
    GenServer.call(pid, {:calculate_pnl, asset, current_price})
  end

  @doc """
  Calculates PnL across all positions at given prices.

  ## Parameters

    * `pid` — The PositionManager process
    * `prices` — Map of asset to current price
  """
  @spec calculate_portfolio_pnl(pid() | atom(), %{String.t() => float()}) ::
          {:ok, %{total_unrealized_pnl: float(), positions: [pnl_report()]}}
  def calculate_portfolio_pnl(pid, prices) do
    GenServer.call(pid, {:calculate_portfolio_pnl, prices})
  end

  @doc """
  Handles a position update from a WebSocket event.
  """
  @spec handle_position_update(pid() | atom(), map()) :: :ok
  def handle_position_update(pid, event) do
    GenServer.cast(pid, {:position_update, event})
  end

  @doc """
  Gets the total account value from the last sync.
  """
  @spec get_account_value(pid() | atom()) :: float()
  def get_account_value(pid) do
    GenServer.call(pid, :get_account_value)
  end

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :ets_table)
    ets_opts = if table_name do
      [:named_table, :public, :set, read_concurrency: true]
    else
      [:public, :set, read_concurrency: true]
    end
    ets = :ets.new(table_name || :hyperliquid_positions, ets_opts)

    state = %{
      ets: ets,
      address: Config.hyperliquid_account_address(),
      account_value: 0.0,
      total_margin_used: 0.0,
      maintenance_margin_ratio: 0.0,
      realized_pnls: %{}
    }

    Logger.info("[PositionManager] Initialized with ETS table: #{inspect(ets)}")

    {:ok, state}
  end

  @impl true
  def handle_call(:sync_positions, _from, state) do
    case Client.get_account_info(state.address) do
      {:ok, account_data} ->
        parsed = Models.parse_account(account_data)

        :ets.delete_all_objects(state.ets)

        Enum.each(parsed.positions, fn pos ->
          :ets.insert(state.ets, {pos.asset, pos})
        end)

        account_value =
          case Float.parse(parsed.account_value || "0") do
            {val, _} -> val
            :error -> 0.0
          end

        margin_used =
          case Float.parse(parsed.total_margin_used || "0") do
            {val, _} -> val
            :error -> 0.0
          end

        updated_state = %{
          state
          | account_value: account_value,
            total_margin_used: margin_used,
            maintenance_margin_ratio: parse_float(parsed.maintenance_margin_ratio)
        }

        Logger.info("[PositionManager] Synced #{length(parsed.positions)} positions")
        {:reply, {:ok, parsed.positions}, updated_state}

      {:error, reason} ->
        Logger.error("[PositionManager] Sync failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    positions =
      state.ets
      |> :ets.tab2list()
      |> Enum.map(fn {_, pos} -> pos end)

    {:reply, positions, state}
  end

  @impl true
  def handle_call({:get_position, asset}, _from, state) do
    case :ets.lookup(state.ets, asset) do
      [{^asset, position}] -> {:reply, position, state}
      [] -> {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:calculate_pnl, asset, current_price}, _from, state) do
    result =
      case :ets.lookup(state.ets, asset) do
        [{^asset, position}] ->
          {:ok, build_pnl_report(position, current_price, state.realized_pnls)}

        [] ->
          {:error, :position_not_found}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:calculate_portfolio_pnl, prices}, _from, state) do
    positions =
      state.ets
      |> :ets.tab2list()
      |> Enum.map(fn {asset, pos} ->
        price = Map.get(prices, asset, parse_float(pos.entry_price))
        build_pnl_report(pos, price, state.realized_pnls)
      end)

    total_unrealized = Enum.reduce(positions, 0.0, fn p, acc -> acc + p.unrealized_pnl end)

    report = %{
      total_unrealized_pnl: total_unrealized,
      positions: positions
    }

    {:reply, {:ok, report}, state}
  end

  @impl true
  def handle_call(:get_account_value, _from, state) do
    {:reply, state.account_value, state}
  end

  @impl true
  def handle_cast({:position_update, event}, state) do
    try do
      handle_ws_position_event(event, state)
    rescue
      e ->
        Logger.error("[PositionManager] WS event handler crashed: #{Exception.message(e)}")
    catch
      kind, reason ->
        Logger.error("[PositionManager] WS event handler threw #{kind}: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  defp build_pnl_report(position, current_price, realized_pnls) do
    entry_price = parse_float(position.entry_price)
    size = parse_float(position.size)
    liq_price = parse_float(position.liquidation_price)

    unrealized_pnl =
      if entry_price > 0 and size != 0 do
        if size > 0 do
          (current_price - entry_price) * abs(size)
        else
          (entry_price - current_price) * abs(size)
        end
      else
        0.0
      end

    unrealized_pnl_pct =
      if entry_price > 0 do
        (unrealized_pnl / (entry_price * abs(size))) * 100
      else
        0.0
      end

    realized = Map.get(realized_pnls, position.asset, 0.0)

    %{
      asset: position.asset,
      entry_price: entry_price,
      current_price: current_price,
      size: size,
      unrealized_pnl: unrealized_pnl,
      unrealized_pnl_pct: unrealized_pnl_pct,
      realized_pnl: realized,
      is_long: size > 0,
      liquidation_price: liq_price
    }
  end

  defp handle_ws_position_event(%{"channel" => "user"} = event, state) do
    asset_positions = get_in(event, ["data", "assetPositions"]) || []

    Enum.each(asset_positions, fn raw_pos ->
      position = Models.parse_position(raw_pos)
      :ets.insert(state.ets, {position.asset, position})
    end)

    margin_summary = get_in(event, ["data", "crossMarginSummary"]) || %{}

    updated =
      if margin_summary != %{} do
        %{
          state
          | account_value: parse_float(margin_summary["accountValue"]),
            total_margin_used: parse_float(margin_summary["totalMarginUsed"])
        }
      else
        state
      end

    Map.put(updated, :__struct__, nil)
  end

  defp handle_ws_position_event(_event, state), do: state

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp parse_float(num) when is_number(num), do: num

end

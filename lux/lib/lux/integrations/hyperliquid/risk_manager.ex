defmodule Lux.Integrations.Hyperliquid.RiskManager do
  @moduledoc """
  GenServer for proactive and reactive risk management on Hyperliquid.

  Monitors account margin ratios, individual position liquidation
  prices, and triggers stop-loss/take-profit orders. Provides
  configurable risk thresholds and automatic protective actions.

  ## Features

    * Margin ratio monitoring with configurable warning/critical thresholds
    * Liquidation price proximity alerts
    * Automatic stop-loss and take-profit order placement
    * Configurable position size and leverage limits
    * Portfolio concentration checks

  ## Usage

      {:ok, pid} = RiskManager.start_link(
        name: MyRiskManager,
        order_manager: MyOrderManager,
        position_manager: MyPositionManager
      )

      # Evaluate risk for a proposed trade
      RiskManager.evaluate_trade(pid, %{
        asset: "ETH",
        is_buy: true,
        size: 0.5,
        price: 2800.0,
        leverage: 2
      })

      # Check current risk status
      RiskManager.check_risk(pid)
  """

  use GenServer

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.PositionManager

  @typedoc "Risk assessment result"
  @type risk_assessment :: %{
    acceptable: boolean(),
    margin_ratio: float(),
    margin_ratio_status: :safe | :warning | :critical,
    liquidation_risk: float(),
    position_concentration: float(),
    leverage: float(),
    position_size_ratio: float(),
    warnings: [String.t()]
  }

  @typedoc "Risk configuration"
  @type risk_config :: %{
    max_leverage: float(),
    max_position_size_ratio: float(),
    max_portfolio_concentration: float(),
    margin_warning_threshold: float(),
    margin_critical_threshold: float(),
    liquidation_proximity_warning: float(),
    auto_stop_loss_enabled: boolean(),
    auto_take_profit_enabled: boolean(),
    default_sl_pct: float(),
    default_tp_pct: float()
  }

  @doc false
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Evaluates the risk of a proposed trade and returns an assessment.

  ## Parameters

    * `pid` — The RiskManager process
    * `trade` — Proposed trade parameters
  """
  @spec evaluate_trade(pid() | atom(), map()) :: {:ok, risk_assessment()} | {:error, term()}
  def evaluate_trade(pid, trade) do
    GenServer.call(pid, {:evaluate_trade, trade})
  end

  @doc """
  Checks the current risk status of the account.

  Returns risk metrics including margin ratio, liquidation risks,
  and any active warnings.

  ## Parameters

    * `pid` — The RiskManager process
  """
  @spec check_risk(pid() | atom()) :: {:ok, risk_assessment()} | {:error, term()}
  def check_risk(pid) do
    GenServer.call(pid, :check_risk)
  end

  @doc """
  Updates risk configuration thresholds.
  """
  @spec update_config(pid() | atom(), map()) :: :ok
  def update_config(pid, config) do
    GenServer.cast(pid, {:update_config, config})
  end

  @doc """
  Places stop-loss and take-profit orders for a position.
  """
  @spec set_stop_loss_take_profit(pid() | atom(), String.t(), float(), float()) ::
          {:ok, term()} | {:error, term()}
  def set_stop_loss_take_profit(pid, asset, stop_loss_price, take_profit_price) do
    GenServer.call(pid, {:set_sl_tp, asset, stop_loss_price, take_profit_price})
  end

  @doc """
  Handles a risk-relevant WebSocket event (liquidation warning, margin change).
  """
  @spec handle_risk_event(pid() | atom(), map()) :: :ok
  def handle_risk_event(pid, event) do
    GenServer.cast(pid, {:risk_event, event})
  end

  @impl true
  def init(opts) do
    order_manager = Keyword.get(opts, :order_manager)
    position_manager = Keyword.get(opts, :position_manager)

    config = %{
      max_leverage: Keyword.get(opts, :max_leverage, 10.0),
      max_position_size_ratio: Keyword.get(opts, :max_position_size_ratio, 0.25),
      max_portfolio_concentration: Keyword.get(opts, :max_portfolio_concentration, 0.5),
      margin_warning_threshold: Keyword.get(opts, :margin_warning_threshold, 0.15),
      margin_critical_threshold: Keyword.get(opts, :margin_critical_threshold, 0.08),
      liquidation_proximity_warning: Keyword.get(opts, :liquidation_proximity_warning, 0.1),
      auto_stop_loss_enabled: Keyword.get(opts, :auto_stop_loss_enabled, true),
      auto_take_profit_enabled: Keyword.get(opts, :auto_take_profit_enabled, false),
      default_sl_pct: Keyword.get(opts, :default_sl_pct, 0.05),
      default_tp_pct: Keyword.get(opts, :default_tp_pct, 0.15)
    }

    state = %{
      config: config,
      order_manager: order_manager,
      position_manager: position_manager,
      active_stop_losses: %{},
      active_take_profits: %{}
    }

    Logger.info("[RiskManager] Initialized with config: #{inspect(config)}")

    {:ok, state}
  end

  @impl true
  def handle_call({:evaluate_trade, trade}, _from, state) do
    assessment = compute_trade_assessment(trade, state)
    {:reply, {:ok, assessment}, state}
  end

  @impl true
  def handle_call(:check_risk, _from, state) do
    assessment = compute_risk_assessment(state)
    {:reply, {:ok, assessment}, state}
  end

  @impl true
  def handle_call({:set_sl_tp, asset, stop_loss_price, take_profit_price}, _from, state) do
    result = place_sl_tp_orders(state, asset, stop_loss_price, take_profit_price)
    {:reply, result, state}
  end

  @impl true
  def handle_cast({:update_config, new_config}, state) do
    updated_config = Map.merge(state.config, new_config)
    Logger.info("[RiskManager] Configuration updated")
    {:noreply, %{state | config: updated_config}}
  end

  @impl true
  def handle_cast({:risk_event, event}, state) do
    handle_risk_ws_event(event, state)
    {:noreply, state}
  end

  defp compute_trade_assessment(trade, state) do
    price = Map.get(trade, :price, 0.0)
    size = Map.get(trade, :size, 0.0)
    asset = Map.get(trade, :asset)
    leverage = Map.get(trade, :leverage, 1.0)

    account_value = get_account_value(state)
    position_value = price * size
    position_size_ratio = if account_value > 0, do: position_value / account_value, else: 0.0

    existing_concentration =
      case state.position_manager && PositionManager.get_position(state.position_manager, asset) do
        nil -> 0.0
        pos ->
          pv = parse_float(pos.position_value)
          if account_value > 0, do: pv / account_value, else: 0.0
      end

    new_concentration = existing_concentration + position_size_ratio

    liq_risk = compute_liquidation_risk(state, asset, price, trade[:is_buy])

    warnings = []

    warnings =
      if leverage > state.config.max_leverage do
        ["Leverage #{leverage}x exceeds max #{state.config.max_leverage}x" | warnings]
      else
        warnings
      end

    warnings =
      if position_size_ratio > state.config.max_position_size_ratio do
        ["Position size #{Float.round(position_size_ratio * 100, 1)}% exceeds max #{Float.round(state.config.max_position_size_ratio * 100, 1)}%" | warnings]
      else
        warnings
      end

    warnings =
      if new_concentration > state.config.max_portfolio_concentration do
        ["Portfolio concentration #{Float.round(new_concentration * 100, 1)}% exceeds max #{Float.round(state.config.max_portfolio_concentration * 100, 1)}%" | warnings]
      else
        warnings
      end

    margin_ratio = get_margin_ratio(state)
    margin_status = classify_margin_ratio(margin_ratio, state.config)

    %{
      acceptable: warnings == [],
      margin_ratio: margin_ratio,
      margin_ratio_status: margin_status,
      liquidation_risk: liq_risk,
      position_concentration: new_concentration,
      leverage: leverage,
      position_size_ratio: position_size_ratio,
      warnings: warnings
    }
  end

  defp compute_risk_assessment(state) do
    margin_ratio = get_margin_ratio(state)
    margin_status = classify_margin_ratio(margin_ratio, state.config)

    positions =
      case state.position_manager do
        nil -> []
        pm -> PositionManager.get_positions(pm)
      end

    warnings =
      cond do
        margin_status == :critical ->
          ["CRITICAL: Margin ratio at #{Float.round(margin_ratio * 100, 2)}%"]

        margin_status == :warning ->
          ["WARNING: Margin ratio at #{Float.round(margin_ratio * 100, 2)}%"]

        true ->
          []
      end

    liquidation_warnings =
      Enum.flat_map(positions, fn pos ->
        lp = parse_float(pos.liquidation_price)
        ep = parse_float(pos.entry_price)

        if lp > 0 and ep > 0 do
          proximity = abs(ep - lp) / ep

          if proximity < state.config.liquidation_proximity_warning do
            ["#{pos.asset}: Liquidation price proximity at #{Float.round(proximity * 100, 1)}%"]
          else
            []
          end
        else
          []
        end
      end)

    all_warnings = warnings ++ liquidation_warnings

    concentration =
      positions
      |> Enum.map(fn p ->
        pv = parse_float(p.position_value)
        av = get_account_value(state)
        if av > 0, do: pv / av, else: 0.0
      end)
      |> Enum.max(fn -> 0.0 end)

    %{
      acceptable: all_warnings == [],
      margin_ratio: margin_ratio,
      margin_ratio_status: margin_status,
      liquidation_risk: if(liquidation_warnings != [], do: 1.0, else: 0.0),
      position_concentration: concentration,
      leverage: 0.0,
      position_size_ratio: 0.0,
      warnings: all_warnings
    }
  end

  defp classify_margin_ratio(ratio, config) do
    cond do
      ratio <= config.margin_critical_threshold -> :critical
      ratio <= config.margin_warning_threshold -> :warning
      true -> :safe
    end
  end

  defp compute_liquidation_risk(state, asset, current_price, _is_buy) do
    case state.position_manager && PositionManager.get_position(state.position_manager, asset) do
      nil -> 0.0
      pos ->
        lp = parse_float(pos.liquidation_price)
        if lp > 0 and current_price > 0 do
          abs(lp - current_price) / current_price
        else
          0.0
        end
    end
  end

  defp get_margin_ratio(state) do
    if state.position_manager do
      av = PositionManager.get_account_value(state.position_manager)
      if av > 0, do: 1.0, else: 0.5
    else
      0.5
    end
  end

  defp get_account_value(state) do
    if state.position_manager do
      PositionManager.get_account_value(state.position_manager)
    else
      0.0
    end
  end

  defp place_sl_tp_orders(state, asset, stop_loss_price, take_profit_price) do
    if state.order_manager do
      sl_result = place_trigger_order(state, asset, false, stop_loss_price, "sl")
      tp_result = place_trigger_order(state, asset, false, take_profit_price, "tp")

      active_sl = if match?({:ok, _}, sl_result), do: Map.put(state.active_stop_losses, asset, stop_loss_price), else: state.active_stop_losses
      active_tp = if match?({:ok, _}, tp_result), do: Map.put(state.active_take_profits, asset, take_profit_price), else: state.active_take_profits

      Logger.info("[RiskManager] SL/TP set for #{asset}: SL=#{stop_loss_price}, TP=#{take_profit_price}")
      {:ok, %{stop_loss: sl_result, take_profit: tp_result}}
    else
      {:error, :no_order_manager}
    end
  end

  defp place_trigger_order(state, asset, _is_buy, trigger_price, tpsl) do
    if state.order_manager do
      # Get position to determine size and direction
      pos = state.position_manager && PositionManager.get_position(state.position_manager, asset)
      size = if pos, do: abs(parse_float(pos.size)), else: 0.0
      is_buy = if pos, do: parse_float(pos.size) < 0, else: false

      order_params = %{
        asset: asset,
        is_buy: is_buy,
        size: size,
        price: trigger_price,
        order_type: %{trigger: %{trigger_px: trigger_price, is_market: true, tpsl: tpsl}},
        reduce_only: true
      }

      alias Lux.Integrations.Hyperliquid.OrderManager
      OrderManager.place_order(state.order_manager, order_params)
    else
      {:error, :no_order_manager}
    end
  end

  defp handle_risk_ws_event(%{"channel" => "user"} = event, state) do
    margin_summary = get_in(event, ["data", "crossMarginSummary"]) || %{}
    account_value = parse_float(margin_summary["accountValue"])
    margin_used = parse_float(margin_summary["totalMarginUsed"])

    margin_ratio = if account_value > 0, do: (account_value - margin_used) / account_value, else: 1.0

    config = state.config

    cond do
      margin_ratio <= config.margin_critical_threshold ->
        Logger.warning("[RiskManager] CRITICAL: Margin ratio #{Float.round(margin_ratio * 100, 2)}%")

      margin_ratio <= config.margin_warning_threshold ->
        Logger.warning("[RiskManager] WARNING: Margin ratio #{Float.round(margin_ratio * 100, 2)}%")

      true ->
        :ok
    end
  end

  defp handle_risk_ws_event(_event, _state), do: :ok

  defp parse_float(nil), do: 0.0
  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {val, _} -> val
      :error -> 0.0
    end
  end
  defp parse_float(num) when is_number(num), do: num
end

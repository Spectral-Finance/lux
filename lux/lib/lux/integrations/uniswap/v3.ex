defmodule Lux.Integrations.Uniswap.V3 do
  @moduledoc """
  Comprehensive Uniswap V3 integration for advanced liquidity management
  and optimal trading strategies.
  """

  alias Lux.Integrations.Uniswap.V3.{
    LiquidityManager,
    PositionManager,
    FeeManager,
    PriceOptimizer,
    PositionMonitor,
    Rebalancer
  }

  @doc """
  Returns the module version.
  """
  @spec version :: String.t()
  def version, do: "1.0.0"

  # Delegate to sub-modules for clean API
  defdelegate create_position(params), to: PositionManager
  defdelegate close_position(position_id), to: PositionManager
  defdelegate get_position(position_id), to: PositionManager
  defdelegate list_positions(filters \\ %{}), to: PositionManager

  defdelegate add_liquidity(position_id, amount), to: LiquidityManager
  defdelegate remove_liquidity(position_id, percentage), to: LiquidityManager
  defdelegate optimize_range(position_id), to: LiquidityManager

  defdelegate collect_fees(position_id), to: FeeManager
  defdelegate reinvest_fees(position_id), to: FeeManager

  defdelegate get_optimal_fee_tier(token_a, token_b, volume), to: PriceOptimizer
  defdelegate calculate_price_range(position_id, strategy), to: PriceOptimizer

  defdelegate get_position_health(position_id), to: PositionMonitor
  defdelegate monitor_positions, to: PositionMonitor

  defdelegate rebalance_position(position_id), to: Rebalancer
  defdelegate auto_rebalance(enabled), to: Rebalancer
end
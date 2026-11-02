defmodule Lux.Defi.UniswapV3.RebalanceEngine do
  @moduledoc """
  Automated rebalancing engine for Uniswap V3 concentrated liquidity positions:
  - Out-of-range detection and proximity alerts
  - Cost-benefit viability evaluation (gas cost vs projected fee recovery)
  - Execution planning (burn old position, collect fees, compute new centered range, mint new position)
  """

  alias Lux.Defi.UniswapV3.PositionManager
  alias Lux.Defi.UniswapV3.RangeOptimizer

  @type rebalance_plan :: %{
          action: :rebalance | :hold,
          reason: String.t(),
          old_position_id: pos_integer() | String.t(),
          new_tick_lower: integer(),
          new_tick_upper: integer(),
          new_price_lower: float(),
          new_price_upper: float(),
          viable?: boolean(),
          estimated_gas_cost_usd: float()
        }

  @doc """
  Checks if a position requires rebalancing based on current tick, boundary proximity, or out-of-range status.
  `buffer_ratio`: proximity threshold towards edges (default 0.85).
  """
  @spec needs_rebalance?(PositionManager.position(), integer(), float()) :: {:ok, boolean(), atom()}
  def needs_rebalance?(position, current_tick, buffer_ratio \\ 0.85) when is_integer(current_tick) do
    cond do
      current_tick < position.tick_lower ->
        {:ok, true, :out_of_range_below}

      current_tick >= position.tick_upper ->
        {:ok, true, :out_of_range_above}

      true ->
        # Position is inside range, check if close to boundary
        total_span = position.tick_upper - position.tick_lower
        distance_from_center = abs(current_tick - div(position.tick_lower + position.tick_upper, 2))
        max_allowed_distance = div(total_span, 2) * buffer_ratio

        if distance_from_center >= max_allowed_distance do
          {:ok, true, :approaching_boundary}
        else
          {:ok, false, :optimal}
        end
    end
  end

  @doc """
  Generates a comprehensive rebalance execution plan for a position.
  """
  @spec plan_rebalance(PositionManager.position(), integer(), RangeOptimizer.strategy(), keyword()) ::
          {:ok, rebalance_plan()} | {:error, term()}
  def plan_rebalance(position, current_tick, strategy \\ :moderate, opts \\ []) when is_integer(current_tick) do
    with {:ok, needs?, reason} <- needs_rebalance?(position, current_tick, Keyword.get(opts, :buffer_ratio, 0.85)) do
      if not needs? do
        {:ok,
         %{
           action: :hold,
           reason: "Position is currently optimal (#{reason})",
           old_position_id: position.token_id,
           new_tick_lower: position.tick_lower,
           new_tick_upper: position.tick_upper,
           new_price_lower: 0.0,
           new_price_upper: 0.0,
           viable?: true,
           estimated_gas_cost_usd: 0.0
         }}
      else
        # Compute new centered range
        case RangeOptimizer.calculate_range(current_tick, position.fee, strategy, opts) do
          {:ok, new_range} ->
            gas_cost_usd = Keyword.get(opts, :gas_cost_usd, 15.0)
            position_capital_usd = Keyword.get(opts, :position_capital_usd, 5000.0)

            # Rebalancing is viable if gas cost represents < 2% of position capital
            viable = gas_cost_usd / max(position_capital_usd, 1.0) < 0.02

            {:ok,
             %{
               action: :rebalance,
               reason: "Triggered by #{reason}",
               old_position_id: position.token_id,
               new_tick_lower: new_range.tick_lower,
               new_tick_upper: new_range.tick_upper,
               new_price_lower: new_range.price_lower,
               new_price_upper: new_range.price_upper,
               viable?: viable,
               estimated_gas_cost_usd: gas_cost_usd
             }}

          {:error, err} ->
            {:error, err}
        end
      end
    end
  end
end

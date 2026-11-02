defmodule Lux.Defi.UniswapV3.ImpermanentLoss do
  @moduledoc """
  Impermanent Loss (IL) modeling and protection for Uniswap V3:
  - Standard V2 benchmark comparison
  - Concentrated liquidity amplified IL calculation
  - Net position PnL (Fees accrued vs IL)
  - Stop-loss and risk warning triggers
  """

  @doc """
  Calculates standard Uniswap V2 impermanent loss percentage given a price ratio k = P_current / P_entry.
  IL = 2 * sqrt(k) / (1 + k) - 1
  Returns a negative float (e.g. -0.057 for 5.7% loss) or 0.0 if k == 1.
  """
  @spec standard_il(number()) :: float()
  def standard_il(k) when is_number(k) and k > 0 do
    sqrt_k = :math.sqrt(k)
    il = 2.0 * sqrt_k / (1.0 + k) - 1.0
    Float.round(il, 6)
  end

  @doc """
  Calculates concentrated liquidity amplified IL for a position with bounds [P_lower, P_upper]
  and entry price P_entry at current price P_current.
  """
  @spec concentrated_il(number(), number(), number(), number()) :: float()
  def concentrated_il(p_entry, p_current, p_lower, p_upper)
      when p_entry > 0 and p_current > 0 and p_lower > 0 and p_upper > p_lower do
    # When current price equals entry price, IL is 0
    if abs(p_current - p_entry) < 0.000001 do
      0.0
    else
      # Capital efficiency amplification factor
      k = p_current / p_entry
      base_il = standard_il(k)

      ratio = p_lower / p_upper
      sqrt_ratio = :math.sqrt(ratio)
      amplification = 1.0 / max(1.0 - sqrt_ratio, 0.01)

      # Clamped amplified IL: maximum loss is -100% (-1.0)
      amplified = base_il * :math.sqrt(amplification)
      max(Float.round(amplified, 4), -1.0)
    end
  end

  @doc """
  Calculates net PnL in USD comparing total earned fees against estimated impermanent loss impact.
  """
  @spec calculate_net_pnl(number(), float(), number()) :: %{
          net_pnl_usd: float(),
          il_usd: float(),
          fees_usd: float(),
          profitable?: boolean()
        }
  def calculate_net_pnl(initial_capital_usd, il_fraction, fees_earned_usd)
      when is_number(initial_capital_usd) and is_number(il_fraction) and is_number(fees_earned_usd) do
    # il_fraction is negative or 0 (e.g. -0.04)
    il_usd = abs(il_fraction) * initial_capital_usd
    net_pnl = fees_earned_usd - il_usd

    %{
      net_pnl_usd: Float.round(net_pnl, 2),
      il_usd: Float.round(il_usd, 2),
      fees_usd: Float.round(fees_earned_usd, 2),
      profitable?: net_pnl >= 0
    }
  end

  @doc """
  Evaluates whether an impermanent loss stop-loss threshold has been breached.
  """
  @spec stop_loss_triggered?(number(), number(), number(), number(), float()) :: boolean()
  def stop_loss_triggered?(p_entry, p_current, p_lower, p_upper, max_il_threshold \\ 0.08) do
    il = abs(concentrated_il(p_entry, p_current, p_lower, p_upper))
    il >= max_il_threshold
  end
end

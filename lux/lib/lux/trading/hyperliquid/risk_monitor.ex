defmodule Lux.Trading.Hyperliquid.RiskMonitor do
  @moduledoc """
  Portfolio risk monitoring and ASCII dashboard generator for Hyperliquid perpetual positions.
  """

  alias Lux.Trading.Hyperliquid.LiquidationProtector

  @doc """
  Calculates portfolio-wide risk metrics across all active perpetual positions.
  """
  @spec calculate_portfolio_risk(float(), list(map())) :: %{
          effective_leverage: float(),
          max_concentration_pct: float(),
          highest_risk_coin: String.t(),
          highest_risk_tier: atom(),
          portfolio_pnl_usd: float()
        }
  def calculate_portfolio_risk(account_equity, positions) when is_list(positions) do
    total_notional =
      positions
      |> Enum.map(&Map.get(&1, :notional, 0.0))
      |> Enum.sum()

    total_pnl =
      positions
      |> Enum.map(&Map.get(&1, :unrealized_pnl, 0.0))
      |> Enum.sum()

    effective_leverage =
      if account_equity > 0 do
        Float.round(total_notional / account_equity, 2)
      else
        0.0
      end

    max_notional =
      positions
      |> Enum.map(&Map.get(&1, :notional, 0.0))
      |> Enum.max(fn -> 0.0 end)

    concentration =
      if total_notional > 0 do
        Float.round(max_notional / total_notional * 100.0, 2)
      else
        0.0
      end

    worst_position =
      positions
      |> Enum.map(fn p ->
        tier = LiquidationProtector.evaluate_risk_tier(p)
        {p.coin, tier.tier, tier.distance_pct}
      end)
      |> Enum.min_by(fn {_coin, _tier, dist} -> dist end, fn -> {"NONE", :safe, 100.0} end)

    {worst_coin, worst_tier, _} = worst_position

    %{
      effective_leverage: effective_leverage,
      max_concentration_pct: concentration,
      highest_risk_coin: worst_coin,
      highest_risk_tier: worst_tier,
      portfolio_pnl_usd: Float.round(total_pnl, 2)
    }
  end

  @doc """
  Renders an ASCII performance and risk dashboard table for Hyperliquid positions.
  """
  @spec render_dashboard(list(map()), float()) :: String.t()
  def render_dashboard(positions, account_equity) when is_list(positions) do
    header = """
+---------------------------------------------------------------------------------------------------+
|                            HYPERLIQUID PERPETUAL TRADING DASHBOARD                                |
+---------------------------------------------------------------------------------------------------+
| Coin | Dir   | Size       | Entry Px   | Mark Px    | Liq Px     | Dist % | PnL ($)    | ROE %  | Tier |
+------+-------+------------+------------+------------+------------+--------+------------+--------+------+
"""

    rows =
      Enum.map_join(positions, "\n", fn p ->
        coin = (p[:coin] || "ETH") |> String.pad_trailing(4)
        dir = (to_string(p[:direction] || "LONG") |> String.upcase()) |> String.pad_trailing(5)
        sz = to_string(p[:sz] || 0.0) |> String.slice(0, 10) |> String.pad_trailing(10)
        entry = "$#{p[:entry_px] || 0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        mark = "$#{p[:mark_px] || 0}" |> String.slice(0, 10) |> String.pad_trailing(10)
        liq = "$#{p[:liquidation_px] || 0}" |> String.slice(0, 10) |> String.pad_trailing(10)

        dist_val = LiquidationProtector.liquidation_distance_pct(p[:mark_px] || 1.0, p[:liquidation_px] || 0.0)
        dist = "#{dist_val}%" |> String.pad_trailing(6)

        pnl_val = p[:unrealized_pnl] || 0.0
        pnl = "#{if pnl_val >= 0, do: "+", else: ""}$#{pnl_val}" |> String.pad_trailing(10)
        roe = "#{p[:roe_pct] || 0.0}%" |> String.pad_trailing(6)

        tier_info = LiquidationProtector.evaluate_risk_tier(p)
        tier = to_string(tier_info.tier) |> String.upcase() |> String.pad_trailing(4)

        "| #{coin} | #{dir} | #{sz} | #{entry} | #{mark} | #{liq} | #{dist} | #{pnl} | #{roe} | #{tier} |"
      end)

    risk = calculate_portfolio_risk(account_equity, positions)

    summary = """

+---------------------------------------------------------------------------------------------------+
| Equity: $#{Float.round(account_equity, 2)} | Leverage: #{risk.effective_leverage}x | Portfolio PnL: $#{risk.portfolio_pnl_usd} | Max Risk: #{risk.highest_risk_coin} (#{risk.highest_risk_tier})
+---------------------------------------------------------------------------------------------------+
"""

    header <> rows <> summary
  end
end

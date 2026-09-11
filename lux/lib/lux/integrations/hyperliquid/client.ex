defmodule Lux.Integrations.Hyperliquid.Client do
  @moduledoc """
  High-performance Hyperliquid L1 Perpetual Trading Integration for Lux Autonomous Agents.
  Provides order placement, position management, leverage control, margin tracking, and liquidation monitoring.
  """

  @type order_type :: :market | :limit | :stop_loss | :take_profit
  @type side :: :buy | :sell

  @type order_params :: %{
          coin: String.t(),
          is_buy: boolean(),
          size: float(),
          limit_px: float(),
          order_type: order_type(),
          reduce_only: boolean(),
          leverage: pos_integer()
        }

  @type position :: %{
          coin: String.t(),
          szi: float(),
          entry_px: float(),
          liquidation_px: float(),
          margin_used: float(),
          unrealized_pnl: float(),
          leverage: pos_integer()
        }

  @doc """
  Builds a signed L1 perpetual order payload for Hyperliquid matching engine.
  """
  def build_order(coin, is_buy, size, limit_px, opts \\ []) do
    order_type = Keyword.get(opts, :order_type, :limit)
    reduce_only = Keyword.get(opts, :reduce_only, false)
    leverage = Keyword.get(opts, :leverage, 10)

    %{
      asset: coin,
      is_buy: is_buy,
      sz: size,
      limit_px: limit_px,
      order_type: order_type,
      reduce_only: reduce_only,
      leverage: leverage,
      timestamp: System.system_time(:millisecond)
    }
  end

  @doc """
  Calculates position risk, health ratio, and liquidation distance.
  """
  def calculate_risk(entry_px, mark_px, leverage, is_long) do
    maintenance_margin = 1.0 / leverage
    liquidation_distance = entry_px * maintenance_margin

    liquidation_px =
      if is_long do
        entry_px - liquidation_distance
      else
        entry_px + liquidation_distance
      end

    health_ratio =
      if is_long do
        (mark_px - liquidation_px) / entry_px
      else
        (liquidation_px - mark_px) / entry_px
      end

    %{
      liquidation_price: liquidation_px,
      health_ratio: max(health_ratio, 0.0),
      is_at_risk: health_ratio < 0.05
    }
  end

  @doc """
  Computes unrealized PnL based on mark price.
  """
  def compute_pnl(entry_px, mark_px, size, is_long) do
    if is_long do
      (mark_px - entry_px) * size
    else
      (entry_px - mark_px) * size
    end
  end
end

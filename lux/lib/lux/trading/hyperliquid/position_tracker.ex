defmodule Lux.Trading.Hyperliquid.PositionTracker do
  @moduledoc """
  Real-time perpetual position tracking for Hyperliquid:
  - Long & Short direction tracking
  - Unrealized & realized PnL in USD and ROE percentage
  - Notional value and margin allocation
  - Dynamic mark price updating
  """

  @type direction :: :long | :short
  @type margin_mode :: :cross | :isolated

  @type position :: %{
          coin: String.t(),
          direction: direction(),
          sz: float(),
          entry_px: float(),
          mark_px: float(),
          notional: float(),
          leverage: pos_integer(),
          margin_mode: margin_mode(),
          unrealized_pnl: float(),
          roe_pct: float(),
          liquidation_px: float()
        }

  @doc """
  Initializes or updates a tracked position.
  """
  @spec track_position(map()) :: {:ok, position()} | {:error, term()}
  def track_position(params) when is_map(params) do
    coin = Map.get(params, :coin) || Map.get(params, "coin")
    sz = Map.get(params, :sz) || Map.get(params, "sz", 0.0)
    entry_px = Map.get(params, :entry_px) || Map.get(params, "entry_px", 0.0)
    mark_px = Map.get(params, :mark_px) || Map.get(params, "mark_px", entry_px)
    leverage = Map.get(params, :leverage) || Map.get(params, "leverage", 10)
    raw_mode = Map.get(params, :margin_mode) || Map.get(params, "margin_mode", :cross)

    direction =
      if sz >= 0.0, do: :long, else: :short

    abs_sz = abs(sz * 1.0)
    notional = Float.round(abs_sz * mark_px, 2)
    margin_mode = if raw_mode in [:isolated, "isolated"], do: :isolated, else: :cross

    pnl = calculate_pnl(direction, abs_sz, entry_px, mark_px)
    margin_allocated = notional / max(leverage, 1)
    roe = if margin_allocated > 0, do: Float.round(pnl / margin_allocated * 100.0, 2), else: 0.0

    liq_px = calculate_liquidation_price(direction, entry_px, leverage)

    pos = %{
      coin: String.upcase(coin || "ETH"),
      direction: direction,
      sz: abs_sz,
      entry_px: entry_px * 1.0,
      mark_px: mark_px * 1.0,
      notional: notional,
      leverage: leverage,
      margin_mode: margin_mode,
      unrealized_pnl: pnl,
      roe_pct: roe,
      liquidation_px: liq_px
    }

    {:ok, pos}
  end

  @doc """
  Updates position metrics with a new mark price.
  """
  @spec update_mark_price(position(), float()) :: position()
  def update_mark_price(position, new_mark_px) when is_number(new_mark_px) and new_mark_px > 0 do
    notional = Float.round(position.sz * new_mark_px, 2)
    pnl = calculate_pnl(position.direction, position.sz, position.entry_px, new_mark_px)
    margin_allocated = notional / max(position.leverage, 1)
    roe = if margin_allocated > 0, do: Float.round(pnl / margin_allocated * 100.0, 2), else: 0.0

    %{
      position
      | mark_px: new_mark_px * 1.0,
        notional: notional,
        unrealized_pnl: pnl,
        roe_pct: roe
    }
  end

  defp calculate_pnl(:long, sz, entry_px, mark_px) do
    Float.round((mark_px - entry_px) * sz, 2)
  end

  defp calculate_pnl(:short, sz, entry_px, mark_px) do
    Float.round((entry_px - mark_px) * sz, 2)
  end

  defp calculate_liquidation_price(:long, entry_px, leverage) do
    # Approx: P_entry * (1 - 1/leverage + 0.01)
    mmr = 0.01
    liq = entry_px * (1.0 - 1.0 / max(leverage, 1) + mmr)
    Float.round(max(liq, 0.0), 2)
  end

  defp calculate_liquidation_price(:short, entry_px, leverage) do
    # Approx: P_entry * (1 + 1/leverage - 0.01)
    mmr = 0.01
    liq = entry_px * (1.0 + 1.0 / max(leverage, 1) - mmr)
    Float.round(liq, 2)
  end
end

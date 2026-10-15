defmodule Lux.Exchanges.Hyperliquid do
  @moduledoc """
  Hyperliquid Integration and Perpetual Trading for Lux (#82).

  Provides:
  - Perpetual position margin, leverage, and liquidation price calculation
  - Funding rate APR and delta-neutral carry yield estimation
  - Reduce-only & take-profit/stop-loss order payload construction
  """

  @doc """
  Computes perpetual position metrics including notional value, margin requirement,
  unrealized PnL, and estimated liquidation price.
  """
  @spec evaluate_perp_position(map()) :: {:ok, map()} | {:error, term()}
  def evaluate_perp_position(pos) when is_map(pos) do
    entry = Map.get(pos, :entry_price, 0.0) * 1.0
    mark = Map.get(pos, :mark_price, 0.0) * 1.0
    size = Map.get(pos, :size, 0.0) * 1.0
    leverage = max(1.0, Map.get(pos, :leverage, 1.0) * 1.0)
    maint_margin_ratio = Map.get(pos, :maintenance_margin_ratio, 0.025) * 1.0

    if entry <= 0.0 or mark <= 0.0 or size == 0.0 do
      {:error, :invalid_position_params}
    else
      side = if size > 0, do: :long, else: :short
      abs_size = abs(size)
      notional = abs_size * mark
      initial_margin = abs_size * entry / leverage
      upnl = if side == :long, do: (mark - entry) * abs_size, else: (entry - mark) * abs_size

      liq_price =
        case side do
          :long -> entry * (1.0 - 1.0 / leverage + maint_margin_ratio)
          :short -> entry * (1.0 + 1.0 / leverage - maint_margin_ratio)
        end

      {:ok,
       %{
         side: side,
         notional_usd: Float.round(notional, 4),
         initial_margin_usd: Float.round(initial_margin, 4),
         unrealized_pnl_usd: Float.round(upnl, 4),
         liquidation_price: Float.round(max(0.0, liq_price), 4)
       }}
    end
  end
end

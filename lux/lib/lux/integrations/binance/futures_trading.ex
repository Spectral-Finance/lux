defmodule Lux.Integrations.Binance.FuturesTrading do
  @moduledoc """
  Binance USDⓈ-M Perpetual Futures trading engine:
  - Supports leverage adjustment (1x - 125x)
  - Supports margin type switching (ISOLATED / CROSSED)
  - Position risk monitoring and liquidation price estimation
  - Unrealized PnL and return on equity (ROE) calculations
  """

  @valid_sides ["BUY", "SELL"]
  @valid_order_types ["LIMIT", "MARKET", "STOP", "STOP_MARKET", "TAKE_PROFIT", "TAKE_PROFIT_MARKET"]
  @valid_position_sides ["BOTH", "LONG", "SHORT"]

  @doc """
  Builds parameters for placing a USDⓈ-M Futures order.
  """
  @spec build_futures_order(map()) :: {:ok, map()} | {:error, String.t()}
  def build_futures_order(params) do
    symbol = Map.get(params, :symbol) || Map.get(params, "symbol")
    side = (Map.get(params, :side) || Map.get(params, "side", "")) |> String.upcase()
    type = (Map.get(params, :type) || Map.get(params, "type", "LIMIT")) |> String.upcase()
    quantity = Map.get(params, :quantity) || Map.get(params, "quantity", 0.0)
    price = Map.get(params, :price) || Map.get(params, "price")
    reduce_only = Map.get(params, :reduce_only) || Map.get(params, "reduce_only", false)
    pos_side = (Map.get(params, :position_side) || Map.get(params, "position_side", "BOTH")) |> String.upcase()

    cond do
      is_nil(symbol) or symbol == "" ->
        {:error, "Symbol is required"}

      side not in @valid_sides ->
        {:error, "Invalid side: #{side}"}

      type not in @valid_order_types ->
        {:error, "Invalid futures order type: #{type}"}

      quantity <= 0.0 ->
        {:error, "Quantity must be greater than 0"}

      pos_side not in @valid_position_sides ->
        {:error, "Invalid position side: #{pos_side}"}

      type == "LIMIT" and (is_nil(price) or price <= 0.0) ->
        {:error, "Price is required for LIMIT orders"}

      true ->
        payload =
          %{
            symbol: String.upcase(symbol),
            side: side,
            type: type,
            quantity: quantity,
            positionSide: pos_side,
            reduceOnly: reduce_only
          }
          |> maybe_put(:price, price)
          |> maybe_put(:timeInForce, if(type == "LIMIT", do: "GTC", else: nil))

        {:ok, payload}
    end
  end

  @doc """
  Calculates approximate liquidation price for an isolated futures position.
  """
  @spec calculate_liquidation_price(String.t(), float(), pos_integer(), float()) :: float()
  def calculate_liquidation_price(side, entry_price, leverage, maintenance_margin_rate \\ 0.005)
      when entry_price > 0 and leverage > 0 do
    case String.upcase(side) do
      "BUY" -> # Long position
        # Liq Price = Entry * (1 - (1 / Leverage) + MMR)
        liq = entry_price * (1.0 - 1.0 / leverage + maintenance_margin_rate)
        Float.round(max(liq, 0.0), 2)

      "SELL" -> # Short position
        # Liq Price = Entry * (1 + (1 / Leverage) - MMR)
        liq = entry_price * (1.0 + 1.0 / leverage - maintenance_margin_rate)
        Float.round(liq, 2)
    end
  end

  @doc """
  Calculates unrealized profit and loss (uPnL) and return on equity (ROE%).
  """
  @spec calculate_pnl(String.t(), float(), float(), float(), pos_integer()) :: %{
          unrealized_pnl: float(),
          roe_pct: float()
        }
  def calculate_pnl(side, entry_price, mark_price, quantity, leverage)
      when entry_price > 0 and mark_price > 0 and quantity > 0 and leverage > 0 do
    initial_margin = quantity * entry_price / leverage

    upnl =
      case String.upcase(side) do
        "BUY" -> (mark_price - entry_price) * quantity
        "SELL" -> (entry_price - mark_price) * quantity
      end

    roe = if initial_margin > 0, do: upnl / initial_margin * 100.0, else: 0.0

    %{
      unrealized_pnl: Float.round(upnl, 2),
      roe_pct: Float.round(roe, 2)
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

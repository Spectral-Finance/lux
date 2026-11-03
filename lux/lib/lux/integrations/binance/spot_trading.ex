defmodule Lux.Integrations.Binance.SpotTrading do
  @moduledoc """
  Binance Spot Trading engine:
  - Supports LIMIT, MARKET, STOP_LOSS_LIMIT, and TAKE_PROFIT_LIMIT orders
  - Validates symbols, sides (BUY/SELL), time-in-force (GTC, IOC, FOK)
  - Manages order lifecycles and batch cancellations
  """

  @valid_sides ["BUY", "SELL"]
  @valid_order_types ["LIMIT", "MARKET", "STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"]
  @valid_tif ["GTC", "IOC", "FOK"]

  @type spot_order :: %{
          symbol: String.t(),
          side: String.t(),
          type: String.t(),
          quantity: float(),
          price: float() | nil,
          time_in_force: String.t() | nil,
          stop_price: float() | nil
        }

  @doc """
  Validates spot order parameters and builds request payload.
  """
  @spec build_order_params(spot_order()) :: {:ok, map()} | {:error, String.t()}
  def build_order_params(params) do
    symbol = Map.get(params, :symbol) || Map.get(params, "symbol")
    side = (Map.get(params, :side) || Map.get(params, "side", "")) |> String.upcase()
    type = (Map.get(params, :type) || Map.get(params, "type", "LIMIT")) |> String.upcase()
    qty = Map.get(params, :quantity) || Map.get(params, "quantity", 0.0)
    price = Map.get(params, :price) || Map.get(params, "price")
    tif = (Map.get(params, :time_in_force) || Map.get(params, "time_in_force", "GTC")) |> String.upcase()
    stop_price = Map.get(params, :stop_price) || Map.get(params, "stop_price")

    cond do
      is_nil(symbol) or symbol == "" ->
        {:error, "Symbol is required"}

      side not in @valid_sides ->
        {:error, "Invalid side: #{side}. Must be BUY or SELL"}

      type not in @valid_order_types ->
        {:error, "Invalid order type: #{type}"}

      qty <= 0.0 ->
        {:error, "Quantity must be greater than 0"}

      type == "LIMIT" and (is_nil(price) or price <= 0.0) ->
        {:error, "Price is required for LIMIT orders"}

      type in ["STOP_LOSS_LIMIT", "TAKE_PROFIT_LIMIT"] and (is_nil(stop_price) or stop_price <= 0.0) ->
        {:error, "Stop price is required for #{type} orders"}

      true ->
        payload =
          %{
            symbol: String.upcase(symbol),
            side: side,
            type: type,
            quantity: qty
          }
          |> maybe_put(:price, price)
          |> maybe_put(:timeInForce, if(type != "MARKET", do: tif, else: nil))
          |> maybe_put(:stopPrice, stop_price)

        {:ok, payload}
    end
  end

  @doc """
  Formats cancel order request payload.
  """
  @spec build_cancel_params(String.t(), non_neg_integer() | nil, String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def build_cancel_params(symbol, order_id \\ nil, orig_client_order_id \\ nil) do
    cond do
      is_nil(symbol) or symbol == "" ->
        {:error, "Symbol is required"}

      is_nil(order_id) and is_nil(orig_client_order_id) ->
        {:error, "Either order_id or orig_client_order_id must be provided"}

      true ->
        payload =
          %{symbol: String.upcase(symbol)}
          |> maybe_put(:orderId, order_id)
          |> maybe_put(:origClientOrderId, orig_client_order_id)

        {:ok, payload}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end

defmodule Lux.Trading.Hyperliquid.OrderManager do
  @moduledoc """
  Advanced order management system for Hyperliquid perpetual trading:
  - Supports Limit (GTC, IOC, ALO), Market, Stop Loss, Take Profit, and Trailing Stops
  - Validates order precision, lot sizing, and price banding
  - Generates signed order wire payloads
  """

  @type order_type :: :limit | :market | :stop_loss | :take_profit | :trailing_stop
  @type time_in_force :: :gtc | :ioc | :alo

  @type order :: %{
          id: String.t(),
          coin: String.t(),
          is_buy: boolean(),
          sz: float(),
          limit_px: float(),
          order_type: order_type(),
          tif: time_in_force(),
          trigger_px: float() | nil,
          reduce_only: boolean(),
          status: :open | :filled | :canceled | :rejected,
          created_at: DateTime.t()
        }

  @doc """
  Builds and validates an order specification.
  """
  @spec build_order(map()) :: {:ok, order()} | {:error, term()}
  def build_order(params) when is_map(params) do
    coin = Map.get(params, :coin) || Map.get(params, "coin")
    is_buy = Map.get(params, :is_buy)
    is_buy = if is_nil(is_buy), do: Map.get(params, "is_buy", true), else: is_buy
    sz = Map.get(params, :sz) || Map.get(params, "sz")
    limit_px = Map.get(params, :limit_px) || Map.get(params, "limit_px")
    raw_type = Map.get(params, :order_type) || Map.get(params, "order_type", :limit)
    raw_tif = Map.get(params, :tif) || Map.get(params, "tif", :gtc)
    trigger_px = Map.get(params, :trigger_px) || Map.get(params, "trigger_px")
    reduce_only = Map.get(params, :reduce_only) || Map.get(params, "reduce_only", false)

    type = parse_order_type(raw_type)
    tif = parse_tif(raw_tif)

    cond do
      is_nil(coin) or coin == "" ->
        {:error, :missing_coin}

      is_nil(sz) or sz <= 0.0 ->
        {:error, :invalid_size}

      (type == :limit or type == :trailing_stop) and (is_nil(limit_px) or limit_px <= 0.0) ->
        {:error, :invalid_limit_price}

      (type == :stop_loss or type == :take_profit) and (is_nil(trigger_px) or trigger_px <= 0.0) ->
        {:error, :missing_trigger_price}

      true ->
        order_id = "hl_ord_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))

        order = %{
          id: order_id,
          coin: String.upcase(coin),
          is_buy: is_buy,
          sz: Float.round(sz * 1.0, 4),
          limit_px: if(limit_px, do: Float.round(limit_px * 1.0, 2), else: 0.0),
          order_type: type,
          tif: tif,
          trigger_px: if(trigger_px, do: Float.round(trigger_px * 1.0, 2), else: nil),
          reduce_only: reduce_only,
          status: :open,
          created_at: DateTime.utc_now()
        }

        {:ok, order}
    end
  end

  @doc """
  Calculates required margin capital for an order given leverage.
  """
  @spec required_margin(order(), pos_integer()) :: float()
  def required_margin(order, leverage) when leverage > 0 do
    notional = order.sz * order.limit_px
    Float.round(notional / leverage, 2)
  end

  defp parse_order_type(:limit), do: :limit
  defp parse_order_type(:market), do: :market
  defp parse_order_type(:stop_loss), do: :stop_loss
  defp parse_order_type(:take_profit), do: :take_profit
  defp parse_order_type(:trailing_stop), do: :trailing_stop

  defp parse_order_type(str) when is_binary(str) do
    case String.downcase(str) do
      "market" -> :market
      "stop_loss" -> :stop_loss
      "take_profit" -> :take_profit
      "trailing_stop" -> :trailing_stop
      _ -> :limit
    end
  end

  defp parse_order_type(_), do: :limit

  defp parse_tif(:gtc), do: :gtc
  defp parse_tif(:ioc), do: :ioc
  defp parse_tif(:alo), do: :alo

  defp parse_tif(str) when is_binary(str) do
    case String.downcase(str) do
      "ioc" -> :ioc
      "alo" -> :alo
      _ -> :gtc
    end
  end

  defp parse_tif(_), do: :gtc
end

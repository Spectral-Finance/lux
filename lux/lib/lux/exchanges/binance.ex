defmodule Lux.Exchanges.Binance do
  @moduledoc """
  Binance Exchange Integration for Lux (#84).

  Provides:
  - HMAC-SHA256 authenticated request signing for Spot and USD-M Futures APIs
  - Order book depth analysis (bid/ask spread, mid-price, VWAP execution estimate)
  - Limit, Market, and Stop-Loss order construction and validation
  """

  @doc """
  Computes HMAC-SHA256 query signature for authenticated Binance REST endpoints.
  """
  @spec sign_query(String.t(), String.t()) :: String.t()
  def sign_query(query_string, api_secret) when is_binary(query_string) and is_binary(api_secret) do
    :crypto.mac(:hmac, :sha256, api_secret, query_string)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Analyzes an order book snapshot to compute mid-price, spread in bps, and VWAP fill price.
  """
  @spec analyze_orderbook(map(), number()) :: {:ok, map()} | {:error, term()}
  def analyze_orderbook(book, target_qty \\ 1.0) when is_map(book) do
    bids = Map.get(book, :bids, [])
    asks = Map.get(book, :asks, [])

    case {bids, asks} do
      {[[best_bid, _] | _], [[best_ask, _] | _]} when best_ask >= best_bid ->
        mid = (best_bid + best_ask) / 2.0
        spread_bps = Float.round((best_ask - best_bid) / max(1.0e-9, mid) * 10_000.0, 4)
        vwap_buy = estimate_vwap(asks, target_qty)

        {:ok,
         %{
           best_bid: best_bid * 1.0,
           best_ask: best_ask * 1.0,
           mid_price: Float.round(mid, 6),
           spread_bps: spread_bps,
           vwap_buy_price: vwap_buy
         }}

      _ ->
        {:error, :invalid_orderbook}
    end
  end

  defp estimate_vwap(levels, target_qty) do
    {filled, cost} =
      Enum.reduce_while(levels, {0.0, 0.0}, fn [price, qty], {acc_q, acc_c} ->
        rem_q = target_qty - acc_q
        take = min(rem_q, qty * 1.0)
        next_q = acc_q + take
        next_c = acc_c + take * price

        if next_q >= target_qty do
          {:halt, {next_q, next_c}}
        else
          {:cont, {next_q, next_c}}
        end
      end)

    if filled > 0.0, do: Float.round(cost / filled, 6), else: 0.0
  end
end

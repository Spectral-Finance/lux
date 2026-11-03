defmodule Lux.Integrations.Coinbase.MarketData do
  @moduledoc """
  Coinbase Advanced Trade market data services:
  - Historical candle retrieval and interval mapping
  - Orderbook Level 2 parsing and liquidity metrics (spread, depth, mid-market price)
  """

  @granularity_map %{
    "1m" => "ONE_MINUTE",
    "5m" => "FIVE_MINUTE",
    "15m" => "FIFTEEN_MINUTE",
    "30m" => "THIRTY_MINUTE",
    "1h" => "ONE_HOUR",
    "2h" => "TWO_HOUR",
    "6h" => "SIX_HOUR",
    "1d" => "ONE_DAY"
  }

  @doc """
  Maps user-friendly interval string (e.g. "1m", "1h") to Coinbase candle granularity enum.
  """
  @spec map_granularity(String.t()) :: String.t()
  def map_granularity(interval) do
    Map.get(@granularity_map, String.downcase(interval), "ONE_HOUR")
  end

  @doc """
  Parses raw candle lists into structured candle maps.
  """
  @spec parse_candles(list(map())) :: list(map())
  def parse_candles(candles) when is_list(candles) do
    Enum.map(candles, fn c ->
      %{
        start: parse_int(c["start"]),
        low: parse_float(c["low"]),
        high: parse_float(c["high"]),
        open: parse_float(c["open"]),
        close: parse_float(c["close"]),
        volume: parse_float(c["volume"])
      }
    end)
  end

  @doc """
  Calculates orderbook spread and liquidity metrics from Level 2 orderbook snapshot.
  """
  @spec evaluate_orderbook(list(map()), list(map())) :: %{
          best_bid: float(),
          best_ask: float(),
          mid_market: float(),
          spread_usd: float(),
          spread_bps: float()
        }
  def evaluate_orderbook(bids, asks) do
    best_bid =
      case bids do
        [%{"price_level" => p} | _] -> parse_float(p)
        [[p, _] | _] -> parse_float(p)
        _ -> 0.0
      end

    best_ask =
      case asks do
        [%{"price_level" => p} | _] -> parse_float(p)
        [[p, _] | _] -> parse_float(p)
        _ -> 0.0
      end

    mid_market = if best_bid > 0 and best_ask > 0, do: Float.round((best_bid + best_ask) / 2.0, 2), else: 0.0
    spread = if best_bid > 0 and best_ask > 0, do: Float.round(best_ask - best_bid, 4), else: 0.0
    spread_bps = if best_bid > 0, do: Float.round(spread / best_bid * 10000.0, 2), else: 0.0

    %{
      best_bid: best_bid,
      best_ask: best_ask,
      mid_market: mid_market,
      spread_usd: spread,
      spread_bps: spread_bps
    }
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0

  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end

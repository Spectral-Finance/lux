defmodule Lux.Prisms.Binance.MarketDepthPrism do
  @moduledoc """
  Processes and summarizes orderbook market depth data.
  """

  use Lux.Prism,
    name: "Binance Market Depth",
    description: "Evaluates orderbook liquidity, spread, and top bid/ask levels",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Market symbol"},
        bids: %{type: :array, description: "List of [price, qty] pairs"},
        asks: %{type: :array, description: "List of [price, qty] pairs"}
      },
      required: ["symbol", "bids", "asks"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        best_bid: %{type: :number},
        best_ask: %{type: :number},
        spread_usd: %{type: :number},
        spread_bps: %{type: :number}
      },
      required: ["symbol", "best_bid", "best_ask", "spread_usd", "spread_bps"]
    }

  def handler(input, _ctx) do
    symbol = Map.get(input, :symbol) || Map.get(input, "symbol", "BTCUSDT")
    bids = Map.get(input, :bids) || Map.get(input, "bids", [])
    asks = Map.get(input, :asks) || Map.get(input, "asks", [])

    best_bid =
      case bids do
        [[p, _] | _] -> parse_num(p)
        [{p, _} | _] -> parse_num(p)
        _ -> 0.0
      end

    best_ask =
      case asks do
        [[p, _] | _] -> parse_num(p)
        [{p, _} | _] -> parse_num(p)
        _ -> 0.0
      end

    spread = if best_bid > 0 and best_ask > 0, do: Float.round(best_ask - best_bid, 4), else: 0.0
    spread_bps = if best_bid > 0, do: Float.round(spread / best_bid * 10000.0, 2), else: 0.0

    {:ok,
     %{
       symbol: symbol,
       best_bid: best_bid,
       best_ask: best_ask,
       spread_usd: spread,
       spread_bps: spread_bps
     }}
  end

  defp parse_num(n) when is_number(n), do: n * 1.0
  defp parse_num(s) when is_binary(s) do
    case Float.parse(s) do
      {v, _} -> v
      :error -> 0.0
    end
  end
  defp parse_num(_), do: 0.0
end

defmodule Lux.Lenses.TradingView.ChartData do
  @moduledoc """
  Lens for fetching OHLCV chart data from TradingView's scanner API.

  Retrieves current price data including open, high, low, close, volume,
  and change metrics for any supported symbol across multiple exchanges and timeframes.

  ## Supported Timeframes
  - `1`, `5`, `15`, `30`, `60`, `120`, `240` (minutes)
  - `D` (daily), `W` (weekly), `M` (monthly)

  ## Examples

      iex> ChartData.focus(%{symbol: "BINANCE:BTCUSDT", interval: "60"})
      {:ok, %{data: [%{symbol: "BINANCE:BTCUSDT", open: 68000.0, ...}], count: 1}}
  """

  require Logger

  use Lux.Lens,
    name: "TradingView Chart Data",
    description: "Fetches OHLCV chart data for technical analysis",
    url: "https://scanner.tradingview.com/crypto/scan",
    method: :post,
    headers: [
      {"Content-Type", "application/json"},
      {"User-Agent", "Lux/1.0"}
    ],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Symbol in EXCHANGE:PAIR format (e.g., BINANCE:BTCUSDT)"
        },
        interval: %{
          type: :string,
          description: "Timeframe: 1, 5, 15, 30, 60, 120, 240, D, W, M",
          enum: ["1", "5", "15", "30", "60", "120", "240", "D", "W", "M"]
        },
        bars: %{
          type: :integer,
          description: "Number of bars to fetch (default: 100)",
          default: 100
        }
      },
      required: ["symbol"]
    }

  @tradingview_scanner_url "https://scanner.tradingview.com"

  @impl true
  def before_focus(params) do
    symbol = Map.get(params, :symbol, params["symbol"])
    {exchange, pair} = parse_symbol(symbol)
    interval = Map.get(params, :interval, Map.get(params, "interval", "D"))

    suffix = interval_to_suffix(interval)

    columns =
      Enum.map(
        ["open", "high", "low", "close", "volume", "change", "change_abs"],
        &"#{&1}#{suffix}"
      ) ++ ["name", "exchange", "description", "type", "currency"]

    body = %{
      "symbols" => %{"tickers" => ["#{exchange}:#{pair}"]},
      "columns" => columns
    }

    market_type = detect_market_type(exchange)

    %{
      url: "#{@tradingview_scanner_url}/#{market_type}/scan",
      body: body
    }
  end

  @impl true
  def after_focus(%{"data" => data}) when is_list(data) do
    results =
      Enum.map(data, fn %{"s" => symbol, "d" => values} ->
        %{
          symbol: symbol,
          open: Enum.at(values, 0),
          high: Enum.at(values, 1),
          low: Enum.at(values, 2),
          close: Enum.at(values, 3),
          volume: Enum.at(values, 4),
          change_pct: Enum.at(values, 5),
          change_abs: Enum.at(values, 6),
          name: Enum.at(values, 7),
          exchange: Enum.at(values, 8),
          description: Enum.at(values, 9),
          type: Enum.at(values, 10),
          currency: Enum.at(values, 11)
        }
      end)

    {:ok, %{data: results, count: length(results)}}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:error, "Unexpected response: #{inspect(other)}"}

  defp parse_symbol(symbol) when is_binary(symbol) do
    case String.split(symbol, ":") do
      [exchange, pair] -> {exchange, pair}
      [pair] -> {"BINANCE", pair}
    end
  end

  defp interval_to_suffix("D"), do: ""
  defp interval_to_suffix("W"), do: "|W"
  defp interval_to_suffix("M"), do: "|M"
  defp interval_to_suffix(min), do: "|#{min}"

  defp detect_market_type(exchange) do
    exchange = String.upcase(exchange)

    cond do
      exchange in ["BINANCE", "COINBASE", "KRAKEN", "BYBIT", "OKX", "BITSTAMP", "BITFINEX"] -> "crypto"
      exchange in ["NASDAQ", "NYSE", "AMEX", "TSX", "LSE"] -> "america"
      exchange in ["HKEX", "SSE", "SZSE", "TSE", "KRX"] -> "asia"
      exchange in ["FX", "FOREX", "OANDA", "FX_IDC"] -> "forex"
      true -> "crypto"
    end
  end
end

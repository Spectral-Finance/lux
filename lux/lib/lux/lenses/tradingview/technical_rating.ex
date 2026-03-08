defmodule Lux.Lenses.TradingView.TechnicalRating do
  @moduledoc """
  Lens for fetching TradingView technical analysis ratings and indicators.

  Retrieves pre-computed technical analysis including:
  - Overall rating (Strong Buy/Buy/Neutral/Sell/Strong Sell)
  - Oscillator ratings (RSI, Stochastic, CCI, ADX, MACD, etc.)
  - Moving average ratings (SMA, EMA across multiple periods)
  - Individual indicator values

  ## Examples

      iex> TechnicalRating.focus(%{symbol: "BINANCE:BTCUSDT", interval: "D"})
      {:ok, %{
        symbol: "BINANCE:BTCUSDT",
        recommendation: "BUY",
        recommendation_value: 0.25,
        oscillators: %{recommendation: "NEUTRAL", ...},
        moving_averages: %{recommendation: "STRONG_BUY", ...}
      }}
  """

  require Logger

  use Lux.Lens,
    name: "TradingView Technical Rating",
    description: "Fetches technical analysis ratings and indicator values from TradingView",
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
          default: "D"
        }
      },
      required: ["symbol"]
    }

  @tradingview_scanner_url "https://scanner.tradingview.com"

  @oscillator_columns [
    "RSI", "Stoch.K", "Stoch.D", "CCI20", "ADX", "ADX+DI", "ADX-DI",
    "AO", "Mom", "MACD.macd", "MACD.signal", "W.R", "BBPower",
    "UO", "Rec.Stoch.RSI", "Rec.WR", "Rec.BBPower", "Rec.UO"
  ]

  @moving_average_columns [
    "SMA10", "EMA10", "SMA20", "EMA20", "SMA30", "EMA30",
    "SMA50", "EMA50", "SMA100", "EMA100", "SMA200", "EMA200",
    "Ichimoku.BLine", "VWMA", "HullMA9"
  ]

  @summary_columns ["Recommend.All", "Recommend.Other", "Recommend.MA"]

  @impl true
  def before_focus(params) do
    symbol = Map.get(params, :symbol, params["symbol"])
    {exchange, pair} = parse_symbol(symbol)
    interval = Map.get(params, :interval, Map.get(params, "interval", "D"))

    suffix = interval_to_suffix(interval)

    all_columns =
      (@summary_columns ++ @oscillator_columns ++ @moving_average_columns)
      |> Enum.map(&"#{&1}#{suffix}")

    body = %{
      "symbols" => %{"tickers" => ["#{exchange}:#{pair}"]},
      "columns" => all_columns
    }

    market_type = detect_market_type(exchange)

    %{
      url: "#{@tradingview_scanner_url}/#{market_type}/scan",
      body: body
    }
  end

  @impl true
  def after_focus(%{"data" => [%{"s" => symbol, "d" => values} | _]}) do
    [rec_all, rec_osc, rec_ma | rest] = values

    {oscillator_values, ma_values} = Enum.split(rest, length(@oscillator_columns))

    oscillators =
      @oscillator_columns
      |> Enum.zip(oscillator_values)
      |> Map.new(fn {name, value} -> {normalize_key(name), value} end)

    moving_averages =
      @moving_average_columns
      |> Enum.zip(ma_values)
      |> Map.new(fn {name, value} -> {normalize_key(name), value} end)

    result = %{
      symbol: symbol,
      recommendation: rating_to_string(rec_all),
      recommendation_value: rec_all,
      oscillators: %{
        recommendation: rating_to_string(rec_osc),
        recommendation_value: rec_osc,
        indicators: oscillators
      },
      moving_averages: %{
        recommendation: rating_to_string(rec_ma),
        recommendation_value: rec_ma,
        indicators: moving_averages
      },
      summary: %{
        overall: rating_to_string(rec_all),
        oscillators: rating_to_string(rec_osc),
        moving_averages: rating_to_string(rec_ma),
        signal_strength: compute_signal_strength(rec_all)
      }
    }

    {:ok, result}
  end

  def after_focus(%{"data" => []}), do: {:error, "No data found for symbol"}
  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:error, "Unexpected response: #{inspect(other)}"}

  defp normalize_key(key) do
    key
    |> String.downcase()
    |> String.replace(".", "_")
    |> String.replace("+", "plus_")
    |> String.replace("-", "minus_")
    |> String.to_atom()
  end

  defp rating_to_string(value) when is_number(value) do
    cond do
      value >= 0.5 -> "STRONG_BUY"
      value >= 0.1 -> "BUY"
      value > -0.1 -> "NEUTRAL"
      value > -0.5 -> "SELL"
      true -> "STRONG_SELL"
    end
  end

  defp rating_to_string(_), do: "NEUTRAL"

  defp compute_signal_strength(value) when is_number(value) do
    abs_val = abs(value)
    cond do
      abs_val >= 0.5 -> :strong
      abs_val >= 0.3 -> :moderate
      abs_val >= 0.1 -> :weak
      true -> :neutral
    end
  end

  defp compute_signal_strength(_), do: :neutral

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
      exchange in ["NASDAQ", "NYSE", "AMEX"] -> "america"
      true -> "crypto"
    end
  end
end

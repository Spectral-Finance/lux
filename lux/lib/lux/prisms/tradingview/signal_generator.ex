defmodule Lux.Prisms.TradingView.SignalGenerator do
  @moduledoc """
  A prism that generates trading signals based on TradingView technical analysis data.

  Analyzes multiple indicators to produce actionable buy/sell/hold signals with
  confidence scores. The signal generation uses a weighted voting system across
  oscillators and moving averages.

  ## Signal Logic

  The generator evaluates:
  - **RSI**: Overbought (>70) → Sell, Oversold (<30) → Buy
  - **MACD**: Bullish crossover → Buy, Bearish crossover → Sell
  - **Stochastic**: K crosses above D from oversold → Buy, K crosses below D from overbought → Sell
  - **ADX**: Trend strength confirmation (ADX > 25 = strong trend)
  - **Moving Averages**: Price vs MA alignment and MA crossovers
  - **CCI**: Above 100 → Buy, Below -100 → Sell
  - **Momentum**: Positive → Buy, Negative → Sell

  ## Examples

      iex> Lux.Prisms.TradingView.SignalGenerator.run(%{
      ...>   symbol: "TSLA",
      ...>   exchange: "NASDAQ",
      ...>   screener: "america",
      ...>   interval: "1d"
      ...> })
      {:ok, %{
        symbol: "NASDAQ:TSLA",
        signal: "BUY",
        confidence: 0.72,
        strength: "STRONG",
        indicators: %{
          rsi: %{signal: "BUY", value: 38.5},
          macd: %{signal: "BUY", crossover: true},
          stochastic: %{signal: "NEUTRAL", k: 45.2, d: 43.1},
          adx: %{trend_strength: "STRONG", value: 28.5},
          ...
        },
        summary: "Strong buy signal: 8 buy, 2 sell, 3 neutral indicators"
      }}
  """

  use Lux.Prism,
    name: "TradingView Signal Generator",
    description: "Generates trading signals from TradingView technical analysis indicators",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading symbol (e.g., TSLA, BTCUSD)"
        },
        exchange: %{
          type: :string,
          description: "Exchange name (e.g., NASDAQ, BINANCE)"
        },
        screener: %{
          type: :string,
          description: "Market screener region",
          default: "america"
        },
        interval: %{
          type: :string,
          description: "Time interval for analysis",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"],
          default: "1d"
        }
      },
      required: ["symbol", "exchange"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Ticker symbol"},
        signal: %{
          type: :string,
          enum: ["STRONG_BUY", "BUY", "NEUTRAL", "SELL", "STRONG_SELL"],
          description: "Trading signal"
        },
        confidence: %{
          type: :number,
          minimum: 0,
          maximum: 1,
          description: "Signal confidence score"
        },
        strength: %{
          type: :string,
          enum: ["WEAK", "MODERATE", "STRONG"],
          description: "Signal strength"
        },
        indicators: %{
          type: :object,
          description: "Individual indicator signals"
        },
        summary: %{
          type: :string,
          description: "Human-readable signal summary"
        }
      },
      required: ["symbol", "signal", "confidence", "strength"]
    }

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  @doc """
  Generates a trading signal based on technical analysis indicators.
  """
  def handler(input, _ctx) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    interval = Map.get(input, :interval, "1d")

    ticker = TradingView.format_ticker(symbol, exchange)

    columns =
      TradingView.recommendation_columns() ++
        TradingView.oscillator_columns() ++
        TradingView.moving_average_columns() ++
        ["close"]

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))
        parsed = Client.parse_scan_response(response, interval_columns)

        case Map.get(parsed, ticker) do
          nil ->
            {:error, "No data returned for #{ticker}"}

          data ->
            {:ok, generate_signal(ticker, data)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_signal(ticker, data) do
    close = data["close"]

    indicator_signals = %{
      rsi: analyze_rsi(data),
      macd: analyze_macd(data),
      stochastic: analyze_stochastic(data),
      adx: analyze_adx(data),
      cci: analyze_cci(data),
      momentum: analyze_momentum(data),
      awesome_oscillator: analyze_ao(data),
      williams_r: analyze_williams_r(data),
      bbpower: analyze_bbpower(data),
      ultimate_oscillator: analyze_uo(data),
      moving_averages: analyze_moving_averages(data, close)
    }

    # Count weighted votes
    {buy_votes, sell_votes, neutral_votes} = count_votes(indicator_signals)
    total_votes = buy_votes + sell_votes + neutral_votes

    # Calculate confidence and direction
    {signal, confidence} = calculate_signal(buy_votes, sell_votes, neutral_votes, total_votes)

    strength =
      cond do
        confidence >= 0.7 -> "STRONG"
        confidence >= 0.4 -> "MODERATE"
        true -> "WEAK"
      end

    %{
      symbol: ticker,
      signal: signal,
      confidence: Float.round(confidence, 2),
      strength: strength,
      indicators: indicator_signals,
      summary:
        "#{strength} #{String.downcase(signal)} signal: " <>
          "#{buy_votes} buy, #{sell_votes} sell, #{neutral_votes} neutral indicators"
    }
  end

  defp analyze_rsi(data) do
    rsi = data["RSI"]
    rsi_prev = data["RSI[1]"]

    signal =
      cond do
        is_nil(rsi) -> "NEUTRAL"
        rsi < 30 -> "BUY"
        rsi > 70 -> "SELL"
        is_number(rsi_prev) and rsi < 30 and rsi > rsi_prev -> "BUY"
        is_number(rsi_prev) and rsi > 70 and rsi < rsi_prev -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: rsi}
  end

  defp analyze_macd(data) do
    macd = data["MACD.macd"]
    signal_line = data["MACD.signal"]

    {signal, crossover} =
      cond do
        is_nil(macd) or is_nil(signal_line) -> {"NEUTRAL", false}
        macd > signal_line and macd > 0 -> {"BUY", true}
        macd > signal_line -> {"BUY", true}
        macd < signal_line and macd < 0 -> {"SELL", true}
        macd < signal_line -> {"SELL", true}
        true -> {"NEUTRAL", false}
      end

    %{signal: signal, macd: macd, signal_line: signal_line, crossover: crossover}
  end

  defp analyze_stochastic(data) do
    k = data["Stoch.K"]
    d = data["Stoch.D"]
    k_prev = data["Stoch.K[1]"]
    d_prev = data["Stoch.D[1]"]

    signal =
      cond do
        is_nil(k) or is_nil(d) ->
          "NEUTRAL"

        k < 20 and is_number(k_prev) and is_number(d_prev) and k > d and k_prev <= d_prev ->
          "BUY"

        k > 80 and is_number(k_prev) and is_number(d_prev) and k < d and k_prev >= d_prev ->
          "SELL"

        k < 20 ->
          "BUY"

        k > 80 ->
          "SELL"

        true ->
          "NEUTRAL"
      end

    %{signal: signal, k: k, d: d}
  end

  defp analyze_adx(data) do
    adx = data["ADX"]
    plus_di = data["ADX+DI"]
    minus_di = data["ADX-DI"]

    trend_strength =
      cond do
        is_nil(adx) -> "NONE"
        adx >= 50 -> "VERY_STRONG"
        adx >= 25 -> "STRONG"
        adx >= 20 -> "MODERATE"
        true -> "WEAK"
      end

    signal =
      cond do
        is_nil(adx) or is_nil(plus_di) or is_nil(minus_di) -> "NEUTRAL"
        adx > 20 and plus_di > minus_di -> "BUY"
        adx > 20 and minus_di > plus_di -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, trend_strength: trend_strength, value: adx}
  end

  defp analyze_cci(data) do
    cci = data["CCI20"]
    cci_prev = data["CCI20[1]"]

    signal =
      cond do
        is_nil(cci) -> "NEUTRAL"
        cci > 100 -> "BUY"
        cci < -100 -> "SELL"
        is_number(cci_prev) and cci > 0 and cci_prev < 0 -> "BUY"
        is_number(cci_prev) and cci < 0 and cci_prev > 0 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: cci}
  end

  defp analyze_momentum(data) do
    mom = data["Mom"]

    signal =
      cond do
        is_nil(mom) -> "NEUTRAL"
        mom > 0 -> "BUY"
        mom < 0 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: mom}
  end

  defp analyze_ao(data) do
    ao = data["AO"]
    ao_prev = data["AO[1]"]

    signal =
      cond do
        is_nil(ao) -> "NEUTRAL"
        is_number(ao_prev) and ao > 0 and ao_prev <= 0 -> "BUY"
        is_number(ao_prev) and ao < 0 and ao_prev >= 0 -> "SELL"
        ao > 0 -> "BUY"
        ao < 0 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: ao}
  end

  defp analyze_williams_r(data) do
    wr = data["W.R"]

    signal =
      cond do
        is_nil(wr) -> "NEUTRAL"
        wr < -80 -> "BUY"
        wr > -20 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: wr}
  end

  defp analyze_bbpower(data) do
    bbp = data["BBPower"]

    signal =
      cond do
        is_nil(bbp) -> "NEUTRAL"
        bbp > 0 -> "BUY"
        bbp < 0 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: bbp}
  end

  defp analyze_uo(data) do
    uo = data["UO"]

    signal =
      cond do
        is_nil(uo) -> "NEUTRAL"
        uo > 70 -> "BUY"
        uo < 30 -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, value: uo}
  end

  defp analyze_moving_averages(data, close) do
    ma_pairs = [
      {"EMA10", "ema10"},
      {"SMA10", "sma10"},
      {"EMA20", "ema20"},
      {"SMA20", "sma20"},
      {"EMA50", "ema50"},
      {"SMA50", "sma50"},
      {"EMA100", "ema100"},
      {"SMA100", "sma100"},
      {"EMA200", "ema200"},
      {"SMA200", "sma200"}
    ]

    results =
      Enum.map(ma_pairs, fn {col, _name} ->
        ma_val = data[col]

        cond do
          is_nil(ma_val) or is_nil(close) -> "NEUTRAL"
          close > ma_val -> "BUY"
          close < ma_val -> "SELL"
          true -> "NEUTRAL"
        end
      end)

    buy_count = Enum.count(results, &(&1 == "BUY"))
    sell_count = Enum.count(results, &(&1 == "SELL"))

    signal =
      cond do
        buy_count > sell_count -> "BUY"
        sell_count > buy_count -> "SELL"
        true -> "NEUTRAL"
      end

    %{signal: signal, buy_count: buy_count, sell_count: sell_count}
  end

  defp count_votes(indicators) do
    votes =
      indicators
      |> Map.values()
      |> Enum.map(fn ind -> ind.signal end)

    buy = Enum.count(votes, &(&1 in ["BUY", "STRONG_BUY"]))
    sell = Enum.count(votes, &(&1 in ["SELL", "STRONG_SELL"]))
    neutral = Enum.count(votes, &(&1 == "NEUTRAL"))

    {buy, sell, neutral}
  end

  defp calculate_signal(buy_votes, sell_votes, _neutral_votes, total_votes) when total_votes > 0 do
    net = (buy_votes - sell_votes) / total_votes
    confidence = abs(net)

    signal =
      cond do
        net >= 0.5 -> "STRONG_BUY"
        net > 0.1 -> "BUY"
        net <= -0.5 -> "STRONG_SELL"
        net < -0.1 -> "SELL"
        true -> "NEUTRAL"
      end

    {signal, confidence}
  end

  defp calculate_signal(_, _, _, _), do: {"NEUTRAL", 0.0}
end

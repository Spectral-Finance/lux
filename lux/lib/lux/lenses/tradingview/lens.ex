defmodule Lux.Lenses.TradingView do
  @moduledoc """
  TradingView technical analysis lens for Lux.

  Provides chart data fetching, technical indicator calculations (SMA, EMA, RSI, MACD,
  Bollinger Bands, Stochastic, ATR), signal generation, multi-timeframe analysis,
  strategy backtesting, and alert management.

  ## Examples

      alias Lux.Lenses.TradingView

      # Fetch historical OHLCV bars
      TradingView.chart_data(%{
        symbol: "BTCUSD",
        exchange: "BINANCE",
        interval: "1h",
        bars: 100
      })

      # Calculate technical indicators
      TradingView.indicators(%{
        symbol: "BTCUSD",
        exchange: "BINANCE",
        indicators: [:sma, :ema, :rsi, :macd, :bollinger],
        period: 14
      })

      # Run market analysis
      TradingView.analysis(%{
        symbol: "ETHUSD",
        exchange: "BINANCE",
        screener: "crypto",
        interval: "1d"
      })

      # Evaluate alerts
      TradingView.evaluate_alerts(%{
        symbol: "BTCUSD",
        exchange: "BINANCE",
        alerts: [
          %{type: :rsi_oversold, params: %{period: 14, threshold: 30}},
          %{type: :ma_crossover, params: %{fast: 9, slow: 21}}
        ]
      })
  """

  alias Lux.Lenses.TradingView

  # ──────────────────────────────────────────────
  # Public API
  # ──────────────────────────────────────────────

  @doc """
  Fetches historical OHLCV chart data.
  """
  def chart_data(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    interval = Keyword.get(opts, :interval, "1d")
    bars = Keyword.get(opts, :bars, 100)

    ticker = format_ticker(symbol, exchange)
    url = build_udf_history_url(ticker, interval)

    case http_get(url) do
      {:ok, body} ->
        process_chart_response(body, ticker, bars)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches TradingView scanner technical analysis summary.
  """
  def analysis(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    screener = Keyword.get(opts, :screener, "crypto")
    interval = Keyword.get(opts, :interval, "1d")

    analysis = fetch_scanner_analysis(symbol, exchange, screener, interval)

    case analysis do
      {:ok, result} ->
        enrich_with_calculations(result)

      other ->
        other
    end
  end

  @doc """
  Calculates technical indicators on historical data.

  Supported indicators: `:sma`, `:ema`, `:rsi`, `:macd`, `:bollinger`, `:stochastic`, `:atr`
  """
  def indicators(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    interval = Keyword.get(opts, :interval, "1d")
    indicator_list = Keyword.get(opts, :indicators, [:sma, :ema, :rsi, :macd, :bollinger])
    period = Keyword.get(opts, :period, 14)
    bars = Keyword.get(opts, :bars, 100)

    with {:ok, chart} <- chart_data(symbol: symbol, exchange: exchange, interval: interval, bars: bars) do
      closes = extract_prices(chart, :close)
      highs = extract_prices(chart, :high)
      lows = extract_prices(chart, :low)
      volumes = extract_prices(chart, :volume)

      calculated =
        Enum.reduce(indicator_list, %{}, fn
          :sma, acc -> Map.put(acc, :sma, calc_sma(closes, period))
          :ema, acc -> Map.put(acc, :ema, calc_ema(closes, period))
          :rsi, acc -> Map.put(acc, :rsi, calc_rsi(closes, period))
          :macd, acc -> Map.put(acc, :macd, calc_macd(closes))
          :bollinger, acc -> Map.put(acc, :bollinger, calc_bollinger(closes, period))
          :stochastic, acc -> Map.put(acc, :stochastic, calc_stochastic(highs, lows, closes, period))
          :atr, acc -> Map.put(acc, :atr, calc_atr(highs, lows, closes, period))
          _, acc -> acc
        end)

      {:ok, %{
        symbol: "#{String.upcase(exchange)}:#{String.upcase(symbol)}",
        interval: interval,
        indicators: calculated,
        current_price: List.last(closes)
      }}
    end
  end

  @doc """
  Evaluates alert conditions against current market data.
  """
  def evaluate_alerts(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    alerts = Keyword.get(opts, :alerts) || raise ArgumentError, "alerts required"
    interval = Keyword.get(opts, :interval, "1d")
    bars = Keyword.get(opts, :bars, 100)

    with {:ok, chart} <- chart_data(symbol: symbol, exchange: exchange, interval: interval, bars: bars) do
      closes = extract_prices(chart, :close)
      highs = extract_prices(chart, :high)
      lows = extract_prices(chart, :low)

      evaluated =
        Enum.map(alerts, fn alert ->
          evaluate_alert(alert, closes, highs, lows)
        end)

      {:ok, %{
        symbol: "#{String.upcase(exchange)}:#{String.upcase(symbol)}",
        interval: interval,
        alerts: evaluated
      }}
    end
  end

  @doc """
  Runs a simple strategy backtest.
  """
  def backtest(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    strategy = Keyword.get(opts, :strategy) || raise ArgumentError, "strategy required"
    interval = Keyword.get(opts, :interval, "1d")

    bars = Keyword.get(opts, :bars, 200)

    with {:ok, chart} <- chart_data(symbol: symbol, exchange: exchange, interval: interval, bars: bars) do
      closes = extract_prices(chart, :close)
      highs = extract_prices(chart, :high)
      lows = extract_prices(chart, :low)
      times = extract_prices(chart, :time)

      result = run_backtest(
        strategy, closes, highs, lows, times,
        Keyword.get(opts, :initial_capital, 10_000.0),
        Keyword.get(opts, :position_size, 1.0)
      )

      {:ok, result}
    end
  end

  @doc """
  Performs multi-timeframe analysis with key indicators across intervals.
  """
  def multi_timeframe_analysis(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    intervals = Keyword.get(opts, :intervals, ["15m", "1h", "4h", "1d"])

    results =
      Enum.map(intervals, fn interval ->
        case indicators(
          symbol: symbol,
          exchange: exchange,
          interval: interval,
          indicators: [:rsi, :macd, :sma, :ema, :bollinger],
          bars: 100
        ) do
          {:ok, data} -> %{interval: interval, data: data}
          {:error, _} -> %{interval: interval, error: "No data"}
        end
      end)

    {:ok, %{
      symbol: "#{String.upcase(exchange)}:#{String.upcase(symbol)}",
      analyses: results,
      consolidated: consolidate_timeframes(results)
    }}
  end

  @doc """
  Generates trading signals from combined indicator analysis.
  """
  def signals(opts \\ []) do
    symbol = Keyword.get(opts, :symbol) || raise ArgumentError, "symbol required"
    exchange = Keyword.get(opts, :exchange) || raise ArgumentError, "exchange required"
    interval = Keyword.get(opts, :interval, "1d")
    bars = Keyword.get(opts, :bars, 150)

    with {:ok} <- {:ok, nil},
         {:ok, chart} <- chart_data(symbol: symbol, exchange: exchange, interval: interval, bars: bars),
         {:ok, ind} <- indicators(
           symbol: symbol,
           exchange: exchange,
           interval: interval,
           indicators: [:sma, :ema, :rsi, :macd, :bollinger, :stochastic, :atr],
           bars: bars
         ) do
      closes = extract_prices(chart, :close)
      signals = generate_signals(closes, ind.indicators)

      {:ok, %{
        symbol: "#{String.upcase(exchange)}:#{String.upcase(symbol)}",
        interval: interval,
        signals: signals,
        price: List.last(closes),
        timestamp: DateTime.utc_now()
      }}
    end
  end

  # ──────────────────────────────────────────────
  # UDF Protocol (Unified Data Format)
  # ──────────────────────────────────────────────

  @doc false
  def build_udf_config_url do
    "https://chart.tradingview.com/tv/public/config"
  end

  @doc false
  def build_udf_symbol_url(ticker) do
    URI.encode("https://symbols.tradingview.com/symbols/#{ticker}")
  end

  @doc false
  def build_udf_history_url(ticker, interval) do
    resolution = interval_to_resolution(interval)
    "https://chart.tradingview.com/tv/history?symbol=#{URI.encode(ticker)}&resolution=#{resolution}"
  end

  @doc false
  def build_scanner_url(screener), do: "https://scanner.tradingview.com/#{screener}/scan"

  @doc false
  def format_ticker(symbol, exchange) do
    "#{String.upcase(exchange)}:#{String.upcase(symbol)}"
  end

  @doc false
  def classify_recommendation(value) when is_number(value) do
    cond do
      value >= 0.5 -> "STRONG_BUY"
      value >= 0.1 -> "BUY"
      value > -0.1 -> "NEUTRAL"
      value > -0.5 -> "SELL"
      true -> "STRONG_SELL"
    end
  end

  def classify_recommendation(nil), do: "NEUTRAL"

  # ──────────────────────────────────────────────
  # Technical Indicators
  # ──────────────────────────────────────────────

  @doc """
  Simple Moving Average
  """
  def calc_sma(data, period) when length(data) >= period do
    data
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn chunk -> Enum.sum(chunk) / period end)
  end

  def calc_sma(data, _period), do: []

  @doc """
  Exponential Moving Average
  """
  def calc_ema(data, period) when length(data) >= period do
    multiplier = 2.0 / (period + 1)
    sma = calc_sma(Enum.take(data, period * 2), period)

    initial_sma = List.last(sma) || Enum.sum(Enum.take(data, period)) / period

    data
    |> Enum.drop(period - 1)
    |> Enum.reduce([], fn price, acc ->
      case acc do
        [] -> [initial_sma]
        [prev | _] -> [(price - prev) * multiplier + prev | acc]
      end
    end)
    |> Enum.reverse()
  end

  def calc_ema(_data, _period), do: []

  @doc """
  Relative Strength Index
  """
  def calc_rsi(data, period) when length(data) > period do
    changes =
      data
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    gains = Enum.map(changes, fn c -> if c > 0, do: c, else: 0.0 end)
    losses = Enum.map(changes, fn c -> if c < 0, do: -c, else: 0.0 end)

    avg_gain = Enum.sum(Enum.take(gains, period)) / period
    avg_loss = Enum.sum(Enum.take(losses, period)) / period

    rsi_values =
      [avg_gain, avg_loss]
      |> Kernel.++(Enum.drop(gains, period))
      |> Kernel.++(Enum.drop(losses, period))
      |> Enum.chunk_every(2)
      |> Enum.scan({avg_gain, avg_loss}, fn [g, l], {prev_g, prev_l} ->
        new_g = (prev_g * (period - 1) + g) / period
        new_l = (prev_l * (period - 1) + l) / period
        {new_g, new_l}
      end)
      |> Enum.map(fn {g, l} ->
        if l == 0, do: 100.0, else: 100.0 - (100.0 / (1.0 + g / l))
      end)

    [nil | rsi_values]
  end

  def calc_rsi(_data, _period), do: []

  @doc """
  MACD (Moving Average Convergence Divergence)
  """
  def calc_macd(data, fast \\ 12, slow \\ 26, signal \\ 9) do
    ema_fast = calc_ema(data, fast)
    ema_slow = calc_ema(data, slow)

    offset = length(ema_fast) - length(ema_slow)
    ema_fast = if offset > 0, do: Enum.drop(ema_fast, offset), else: ema_fast

    macd_line =
      ema_fast
      |> Enum.zip(ema_slow)
      |> Enum.map(fn {f, s} -> f - s end)

    signal_line = calc_ema(macd_line, signal)

    offset2 = length(macd_line) - length(signal_line)
    macd_line = if offset2 > 0, do: Enum.drop(macd_line, offset2), else: macd_line

    histogram =
      macd_line
      |> Enum.zip(signal_line)
      |> Enum.map(fn {m, s} -> m - s end)

    %{
      macd: macd_line,
      signal: signal_line,
      histogram: histogram
    }
  end

  @doc """
  Bollinger Bands
  """
  def calc_bollinger(data, period, multiplier \\ 2.0) do
    sma = calc_sma(data, period)
    offset = length(data) - length(sma)

    bands =
      sma
      |> Enum.with_index()
      |> Enum.map(fn {mean, idx} ->
        chunk = Enum.slice(data, idx + offset, period)
        variance = Enum.reduce(chunk, 0.0, fn x, acc -> acc + (x - mean) ** 2 end) / period
        stddev = :math.sqrt(variance)

        %{
          middle: mean,
          upper: mean + multiplier * stddev,
          lower: mean - multiplier * stddev,
          bandwidth: (mean + multiplier * stddev - (mean - multiplier * stddev)) / mean,
          percent_b: (List.last(chunk) - (mean - multiplier * stddev)) / (2 * multiplier * stddev)
        }
      end)

    %{
      upper: Enum.map(bands, & &1.upper),
      middle: Enum.map(bands, & &1.middle),
      lower: Enum.map(bands, & &1.lower),
      bandwidth: (List.last(bands) || %{})[:bandwidth] || 0.0,
      percent_b: (List.last(bands) || %{})[:percent_b] || 0.0
    }
  end

  @doc """
  Stochastic Oscillator
  """
  def calc_stochastic(highs, lows, closes, period, smooth_k \\ 3, smooth_d \\ 3) do
    raw_k =
      highs
      |> Enum.zip(lows)
      |> Enum.zip(closes)
      |> Enum.chunk_every(period, 1, :discard)
      |> Enum.map(fn chunk ->
        {high_chunk, _} = Enum.unzip(Enum.map(chunk, fn {{h, _}, _} -> {h, h} end))
        {low_chunk, _} = Enum.unzip(Enum.map(chunk, fn {{_, l}, _} -> {l, l} end))
        {_, clos} = Enum.unzip(Enum.map(chunk, fn {_, c} -> {c, c} end))

        highest = Enum.max(high_chunk)
        lowest = Enum.min(low_chunk)
        current_close = List.last(clos)

        if highest == lowest, do: 50.0, else: (current_close - lowest) / (highest - lowest) * 100.0
      end)

    k_line = calc_sma(raw_k, smooth_k)
    d_line = calc_sma(k_line, smooth_d)

    %{
      k: List.last(k_line),
      d: List.last(d_line),
      raw_k: raw_k,
      k_series: k_line,
      d_series: d_line
    }
  end

  @doc """
  Average True Range
  """
  def calc_atr(highs, lows, closes, period) do
    tr_values =
      highs
      |> Enum.zip(lows)
      |> Enum.zip(closes)
      |> Enum.drop(1)
      |> Enum.map(fn {{h, l}, c} ->
        [h - l, abs(h - c), abs(l - c)]
        |> Enum.max()
      end)

    calc_ema(tr_values, period) |> List.last()
  end

  # ──────────────────────────────────────────────
  # Signal Generation
  # ──────────────────────────────────────────────

  @doc false
  def generate_signals(closes, indicators) do
    signals = []

    signals =
      case indicators[:rsi] do
        [rsi | _] when is_number(rsi) ->
          sig = cond do
            rsi >= 70 -> %{type: :overbought, indicator: :rsi, value: rsi, strength: :strong}
            rsi <= 30 -> %{type: :oversold, indicator: :rsi, value: rsi, strength: :strong}
            true -> %{type: :neutral, indicator: :rsi, value: rsi, strength: :weak}
          end
          [sig | signals]
        _ -> signals
      end

    signals =
      if is_map(indicators[:macd]) do
        macd_val = List.last(indicators[:macd].macd || [])
        signal_val = List.last(indicators[:macd].signal || [])

        if macd_val && signal_val do
          sig = cond do
            macd_val > signal_val -> %{type: :bullish, indicator: :macd, value: macd_val, strength: :moderate}
            macd_val < signal_val -> %{type: :bearish, indicator: :macd, value: macd_val, strength: :moderate}
            true -> %{type: :neutral, indicator: :macd, value: macd_val, strength: :weak}
          end
          [sig | signals]
        else
          signals
        end
      else
        signals
      end

    signals =
      if is_map(indicators[:bollinger]) do
        last_close = List.last(closes)
        upper = List.last(indicators[:bollinger].upper || [])
        lower = List.last(indicators[:bollinger].lower || [])
        middle = List.last(indicators[:bollinger].middle || [])

        if last_close && upper && lower && middle do
          sig = cond do
            last_close >= upper -> %{type: :overbought, indicator: :bollinger, value: last_close, strength: :strong}
            last_close <= lower -> %{type: :oversold, indicator: :bollinger, value: last_close, strength: :strong}
            last_close > middle -> %{type: :above_middle, indicator: :bollinger, value: last_close, strength: :weak}
            true -> %{type: :below_middle, indicator: :bollinger, value: last_close, strength: :weak}
          end
          [sig | signals]
        else
          signals
        end
      else
        signals
      end

    signals =
      if is_map(indicators[:stochastic]) do
        k = indicators[:stochastic].k
        d = indicators[:stochastic].d

        if k && d do
          sig = cond do
            k >= 80 -> %{type: :overbought, indicator: :stochastic, value: k, strength: :strong}
            k <= 20 -> %{type: :oversold, indicator: :stochastic, value: k, strength: :strong}
            k > d -> %{type: :bullish_cross, indicator: :stochastic, value: k, strength: :moderate}
            true -> %{type: :neutral, indicator: :stochastic, value: k, strength: :weak}
          end
          [sig | signals]
        else
          signals
        end
      else
        signals
      end

    signals =
      if is_list(indicators[:sma]) && length(indicators[:sma]) > 0 do
        sma_series = indicators[:sma]
        last_sma = List.last(sma_series)
        prev_sma = if length(sma_series) >= 2, do: Enum.at(sma_series, -2), else: last_sma
        last_close = List.last(closes)

        if last_sma && last_close && prev_sma do
          sig = cond do
            last_close > last_sma && last_close <= prev_sma ->
              %{type: :bullish_cross, indicator: :sma, value: last_sma, strength: :moderate}
            last_close < last_sma && last_close >= prev_sma ->
              %{type: :bearish_cross, indicator: :sma, value: last_sma, strength: :moderate}
            last_close > last_sma ->
              %{type: :above, indicator: :sma, value: last_sma, strength: :weak}
            true ->
              %{type: :below, indicator: :sma, value: last_sma, strength: :weak}
          end
          [sig | signals]
        else
          signals
        end
      else
        signals
      end

    Enum.reverse(signals)
  end

  # ──────────────────────────────────────────────
  # Alerts
  # ──────────────────────────────────────────────

  @doc false
  def evaluate_alert(%{type: :rsi_oversold} = alert, closes, _highs, _lows) do
    period = alert[:params][:period] || 14
    threshold = alert[:params][:threshold] || 30
    rsi = calc_rsi(closes, period) |> List.last()

    %{
      type: :rsi_oversold,
      triggered: is_number(rsi) && rsi <= threshold,
      value: rsi,
      threshold: threshold
    }
  end

  def evaluate_alert(%{type: :rsi_overbought} = alert, closes, _highs, _lows) do
    period = alert[:params][:period] || 14
    threshold = alert[:params][:threshold] || 70
    rsi = calc_rsi(closes, period) |> List.last()

    %{
      type: :rsi_overbought,
      triggered: is_number(rsi) && rsi >= threshold,
      value: rsi,
      threshold: threshold
    }
  end

  def evaluate_alert(%{type: :ma_crossover} = alert, closes, _highs, _lows) do
    fast = alert[:params][:fast] || 9
    slow = alert[:params][:slow] || 21
    ema_fast = calc_ema(closes, fast)
    ema_slow = calc_ema(closes, slow)

    {last_fast, prev_fast} = get_last_two(ema_fast)
    {last_slow, prev_slow} = get_last_two(ema_slow)

    triggered =
      is_number(last_fast) && is_number(prev_fast) &&
      is_number(last_slow) && is_number(prev_slow) &&
      prev_fast <= prev_slow && last_fast > last_slow

    %{
      type: :ma_crossover,
      triggered: triggered,
      fast_ma: last_fast,
      slow_ma: last_slow,
      fast_period: fast,
      slow_period: slow
    }
  end

  def evaluate_alert(%{type: :price_above} = alert, closes, _highs, _lows) do
    level = alert[:params][:level] || 0
    last = List.last(closes)

    %{
      type: :price_above,
      triggered: is_number(last) && last >= level,
      value: last,
      level: level
    }
  end

  def evaluate_alert(%{type: :price_below} = alert, closes, _highs, _lows) do
    level = alert[:params][:level] || 0
    last = List.last(closes)

    %{
      type: :price_below,
      triggered: is_number(last) && last <= level,
      value: last,
      level: level
    }
  end

  def evaluate_alert(%{type: :bollinger_breakout} = alert, closes, _highs, _lows) do
    period = alert[:params][:period] || 20
    bb = calc_bollinger(closes, period)
    last_price = List.last(closes)
    last_upper = List.last(bb.upper)
    last_lower = List.last(bb.lower)

    triggered =
      is_number(last_price) && is_number(last_upper) && is_number(last_lower) &&
      (last_price >= last_upper || last_price <= last_lower)

    %{
      type: :bollinger_breakout,
      triggered: triggered,
      price: last_price,
      upper: last_upper,
      lower: last_lower
    }
  end

  def evaluate_alert(unknown, _closes, _highs, _lows) do
    %{type: unknown[:type] || :unknown, triggered: false, error: "Unknown alert type"}
  end

  # ──────────────────────────────────────────────
  # Strategy Backtesting
  # ──────────────────────────────────────────────

  @doc false
  def run_backtest(strategy, closes, highs, lows, times, initial_capital, position_size) do
    results = simulate_trades(strategy, closes, highs, lows, times, initial_capital, position_size)

    %{
      strategy: strategy.name || "Custom",
      initial_capital: initial_capital,
      final_capital: results.final_capital,
      total_return: calc_return(results.final_capital, initial_capital),
      total_trades: results.trades,
      winning_trades: results.wins,
      losing_trades: results.losses,
      win_rate: if(results.trades > 0, do: results.wins / results.trades * 100, else: 0),
      max_drawdown: results.max_drawdown,
      sharpe_ratio: results.sharpe_ratio,
      trades: results.trade_log
    }
  end

  # ──────────────────────────────────────────────
  # Internal helpers
  # ──────────────────────────────────────────────

  defp http_get(url) do
    req_opts =
      [url: url, headers: [{"user-agent", "Lux TradingView Lens"}], max_retries: 2]
      |> Keyword.merge(Application.get_env(:lux, :req_options, []))

    case Req.request(Req.new(req_opts)) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, %Req.TransportError{reason: r}} -> {:error, inspect(r)}
      {:error, e} -> {:error, inspect(e)}
    end
  end

  defp http_post(url, body) do
    req_opts =
      [url: url, headers: [{"content-type", "application/json"}], max_retries: 2]
      |> Keyword.merge(Application.get_env(:lux, :req_options, []))

    case Req.request(Req.new(req_opts), method: :post, json: body) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "HTTP #{status}"}
      {:error, %Req.TransportError{reason: r}} -> {:error, inspect(r)}
      {:error, e} -> {:error, inspect(e)}
    end
  end

  defp process_chart_response(%{"s" => "ok", "t" => times, "c" => closes, "h" => highs, "l" => lows, "o" => opens, "v" => volumes}, _ticker, bars) do
    count = min(length(times), bars)
    indices = Enum.take(Enum.sort(Enum.zip(times, 0..(length(times) - 1))), count)

    bars_data =
      Enum.map(indices, fn {t, i} ->
        %{
          time: t,
          open: Enum.at(opens, i),
          high: Enum.at(highs, i),
          low: Enum.at(lows, i),
          close: Enum.at(closes, i),
          volume: Enum.at(volumes, i)
        }
      end)

    {:ok, %{bars: bars_data}}
  end

  defp process_chart_response(%{"s" => "no_data"} = _body, ticker, _bars) do
    {:error, "No data available for #{ticker}"}
  end

  defp process_chart_response(body, _ticker, _bars) do
    {:error, "Unexpected chart response: #{inspect(body)}"}
  end

  defp fetch_scanner_analysis(symbol, exchange, screener, interval) do
    ticker = format_ticker(symbol, exchange)
    url = build_scanner_url(screener)

    columns = [
      "Recommend.All|#{interval_to_resolution(interval)}",
      "Recommend.MA|#{interval_to_resolution(interval)}",
      "Recommend.Other|#{interval_to_resolution(interval)}",
      "RSI|#{interval_to_resolution(interval)}",
      "MACD.macd|#{interval_to_resolution(interval)}",
      "MACD.signal|#{interval_to_resolution(interval)}",
      "SMA20|#{interval_to_resolution(interval)}",
      "SMA50|#{interval_to_resolution(interval)}",
      "BB.upper|#{interval_to_resolution(interval)}",
      "BB.lower|#{interval_to_resolution(interval)}",
      "close|#{interval_to_resolution(interval)}",
      "volume|#{interval_to_resolution(interval)}",
      "change|#{interval_to_resolution(interval)}"
    ]

    body = %{
      symbols: %{tickers: [ticker], query: %{types: []}},
      columns: columns
    }

    case http_post(url, body) do
      {:ok, %{"data" => [result]}} ->
        parse_scanner_result(result, columns)

      {:ok, _} ->
        {:error, "No scanner data for #{ticker}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_scanner_result(%{"s" => symbol, "d" => values}, columns) do
    kv =
      columns
      |> Enum.zip(values)
      |> Map.new(fn {col, val} -> {strip_interval(col), val} end)

    {:ok, %{symbol: symbol, data: kv}}
  end

  defp strip_interval(col), do: col |> String.split("|") |> hd()

  defp enrich_with_calculations({:ok, result}) do
    data = result.data

    recommendation =
      classify_recommendation(data["Recommend.All"])

    ma_recommendation =
      classify_recommendation(data["Recommend.MA"])

    osc_recommendation =
      classify_recommendation(data["Recommend.Other"])

    {:ok, %{
      symbol: result.symbol,
      recommendation: recommendation,
      summary: %{
        recommendation: data["Recommend.All"],
        buy: count_signal_strength(data["Recommend.All"], data["Recommend.MA"], data["Recommend.Other"], :buy),
        sell: count_signal_strength(data["Recommend.All"], data["Recommend.MA"], data["Recommend.Other"], :sell),
        neutral: count_signal_strength(data["Recommend.All"], data["Recommend.MA"], data["Recommend.Other"], :neutral)
      },
      moving_averages: %{
        recommendation: ma_recommendation,
        computed_signal: data["Recommend.MA"]
      },
      oscillators: %{
        recommendation: osc_recommendation,
        computed_signal: data["Recommend.Other"]
      },
      indicators: %{
        rsi: data["RSI"],
        macd: %{macd: data["MACD.macd"], signal: data["MACD.signal"]},
        sma20: data["SMA20"],
        sma50: data["SMA50"],
        bb_upper: data["BB.upper"],
        bb_lower: data["BB.lower"]
      },
      price: %{
        close: data["close"],
        volume: data["volume"],
        change: data["change"]
      }
    }}
  end

  defp enrich_with_calculations({:error, _} = error), do: error

  defp count_signal_strength(all, ma, other, :buy) do
    [all, ma, other] |> Enum.count(fn v -> is_number(v) and v >= 0.1 end)
  end

  defp count_signal_strength(all, ma, other, :sell) do
    [all, ma, other] |> Enum.count(fn v -> is_number(v) and v <= -0.1 end)
  end

  defp count_signal_strength(all, ma, other, :neutral) do
    [all, ma, other] |> Enum.count(fn v -> is_number(v) and v > -0.1 and v < 0.1 end)
  end

  defp extract_prices(%{bars: bars}, field) do
    Enum.map(bars, & &1[field])
  end

  defp interval_to_resolution(interval) do
    case interval do
      "1m" -> "1"
      "5m" -> "5"
      "15m" -> "15"
      "30m" -> "30"
      "1h" -> "60"
      "2h" -> "120"
      "4h" -> "240"
      "1d" -> "D"
      "1W" -> "W"
      "1M" -> "M"
      _ -> "D"
    end
  end

  defp get_last_two(list) when is_list(list) and length(list) >= 2 do
    {List.last(list), Enum.at(list, -2)}
  end

  defp get_last_two(list) when is_list(list) and length(list) == 1 do
    {List.last(list), List.last(list)}
  end

  defp get_last_two(_), do: {nil, nil}

  defp calc_return(final, initial) when initial > 0 do
    (final - initial) / initial * 100
  end

  defp calc_return(_, _), do: 0.0

  defp simulate_trades(%{entry: entry_fn, exit: exit_fn} = strategy, closes, highs, lows, times, capital, size) do
    simulate_trades_impl(entry_fn, exit_fn, strategy, closes, highs, lows, times, capital, size)
  end

  defp simulate_trades(%{type: :sma_crossover} = strategy, closes, _highs, _lows, times, capital, size) do
    fast = strategy[:fast] || 9
    slow = strategy[:slow] || 21
    ema_fast = calc_ema(closes, fast)
    ema_slow = calc_ema(closes, slow)
    offset = length(closes) - length(ema_fast)

    {_final_cap, _pos, _in_trade, trade_log, wins, losses, peak, max_dd} =
      Enum.zip([ema_fast, ema_slow, times, closes])
      |> Enum.drop(offset)
      |> Enum.reduce({capital, 0.0, false, [], 0, 0, capital, 0.0}, fn
        {f, s, t, price}, {cap, pos, in_trade, log, w, l, peak, mdd} ->
          new_peak = max(peak, cap)
          new_mdd = max(mdd, (new_peak - cap) / new_peak * 100)

          if !in_trade && f > s do
            buy_cost = price * size
            new_cap = cap - buy_cost
            new_log = log ++ [%{time: t, action: :buy, price: price, capital: new_cap}]
            {new_cap, size, true, new_log, w, l, new_peak, new_mdd}
          else
            if in_trade && f < s do
              sell_value = price * pos
              new_cap = cap + sell_value
              profit_loss = sell_value - (Enum.at(log, -1)[:price] * pos) if length(log) > 0
              is_win = profit_loss > 0
              {new_cap, 0.0, false,
               log ++ [%{time: t, action: :sell, price: price, capital: new_cap}],
               w + (if is_win, do: 1, else: 0), l + (if is_win, do: 0, else: 1),
               new_peak, new_mdd}
            else
              {cap, pos, in_trade, log, w, l, new_peak, new_mdd}
            end
          end
      end)

    trades = trade_log |> Enum.chunk_every(2) |> Enum.filter(&(length(&1) == 2)) |> Enum.count()

    %{
      final_capital: _final_cap,
      trades: trades,
      wins: wins,
      losses: losses,
      max_drawdown: max_dd,
      sharpe_ratio: 0.0,
      trade_log: trade_log
    }
  end

  defp simulate_trades(%{type: :rsi_strategy} = strategy, closes, _highs, _lows, times, capital, size) do
    period = strategy[:period] || 14
    oversold = strategy[:oversold] || 30
    overbought = strategy[:overbought] || 70
    rsi = calc_rsi(closes, period)
    offset = length(closes) - length(rsi)

    {_final_cap, _pos, trade_log, wins, losses, _peak, _mdd} =
      Enum.zip([rsi, times, closes])
      |> Enum.drop(offset)
      |> Enum.reduce({capital, 0.0, [], 0, 0, capital, 0.0}, fn
        {r, t, price}, {cap, pos, log, w, l, peak, mdd} ->
          new_peak = max(peak, cap)
          new_mdd = max(mdd, (new_peak - cap) / new_peak * 100)

          if pos == 0 && is_number(r) && r <= oversold do
            buy_cost = price * size
            {cap - buy_cost, size, log ++ [%{time: t, action: :buy, price: price}], w, l, new_peak, new_mdd}
          else
            if pos > 0 && is_number(r) && r >= overbought do
              sell_value = price * pos
              is_win = sell_value > (Enum.at(log, -1)[:price] * pos) if length(log) > 0
              {cap + sell_value, 0.0,
               log ++ [%{time: t, action: :sell, price: price}],
               w + (if is_win, do: 1, else: 0), l + (if is_win, do: 0, else: 1),
               new_peak, new_mdd}
            else
              {cap, pos, log, w, l, new_peak, new_mdd}
            end
          end
      end)

    %{
      final_capital: _final_cap,
      trades: wins + losses,
      wins: wins,
      losses: losses,
      max_drawdown: _mdd,
      sharpe_ratio: 0.0,
      trade_log: trade_log
    }
  end

  defp simulate_trades(_strategy, _closes, _highs, _lows, _times, capital, _size) do
    %{
      final_capital: capital,
      trades: 0,
      wins: 0,
      losses: 0,
      max_drawdown: 0.0,
      sharpe_ratio: 0.0,
      trade_log: []
    }
  end

  defp simulate_trades_impl(entry_fn, exit_fn, _strategy, closes, highs, lows, times, capital, size) do
    {_final_cap, trade_log, wins, losses, _peak, _mdd} =
      Enum.zip([closes, highs, lows, times])
      |> Enum.reduce({capital, [], 0, 0, capital, 0.0}, fn
        {c, h, l, t}, {cap, log, w, wins_acc, peak, mdd} ->
          new_peak = max(peak, cap)
          new_mdd = max(mdd, (new_peak - cap) / new_peak * 100)

          in_position = length(log) > 0 && Enum.at(log, -1)[:action] == :buy

          if !in_position && entry_fn.(%{close: c, high: h, low: l, time: t}) do
            buy_cost = size
            {cap - buy_cost, log ++ [%{time: t, action: :buy, price: c}], w, wins_acc, new_peak, new_mdd}
          else
            if in_position && exit_fn.(%{close: c, high: h, low: l, time: t}) do
              entry_price = Enum.at(log, -1)[:price]
              sell_value = size * c / entry_price
              is_win = sell_value > size
              {cap + sell_value,
               log ++ [%{time: t, action: :sell, price: c}],
               w + (if is_win, do: 1, else: 0), wins_acc + (if is_win, do: 0, else: 1),
               new_peak, new_mdd}
            else
              {cap, log, w, wins_acc, new_peak, new_mdd}
            end
          end
      end)

    %{
      final_capital: _final_cap,
      trades: wins + losses,
      wins: wins,
      losses: losses,
      max_drawdown: _mdd,
      sharpe_ratio: 0.0,
      trade_log: trade_log
    }
  end

  defp consolidate_timeframes(analyses) do
    directions = Enum.map(analyses, fn
      %{data: %{signals: signals}} when is_list(signals) ->
        bullish = Enum.count(signals, &(&1.strength in [:strong, :moderate] && &1.type in [:bullish, :oversold, :above, :above_middle]))
        bearish = Enum.count(signals, &(&1.strength in [:strong, :moderate] && &1.type in [:bearish, :overbought, :below, :below_middle]))
        cond do
          bullish > bearish -> :bullish
          bearish > bullish -> :bearish
          true -> :neutral
        end
      _ -> :neutral
    end)

    bullish_count = Enum.count(directions, &(&1 == :bullish))
    bearish_count = Enum.count(directions, &(&1 == :bearish))

    %{
      overall_bias: cond do
        bullish_count > bearish_count -> :bullish
        bearish_count > bullish_count -> :bearish
        true -> :neutral
      end,
      bullish_timeframes: bullish_count,
      bearish_timeframes: bearish_count,
      neutral_timeframes: Enum.count(directions, &(&1 == :neutral))
    }
  end
end

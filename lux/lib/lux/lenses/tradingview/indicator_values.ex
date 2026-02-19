defmodule Lux.Lenses.TradingView.IndicatorValues do
  @moduledoc """
  Lens for fetching specific technical indicator values from TradingView.

  Retrieves raw indicator values (RSI, MACD, Stochastic, ADX, etc.) and
  moving average values (EMA, SMA at various periods) for a given symbol.

  ## Example

      alias Lux.Lenses.TradingView.IndicatorValues

      # Get all indicator values for Tesla
      IndicatorValues.focus(%{
        symbol: "TSLA",
        exchange: "NASDAQ",
        screener: "america",
        interval: "1d"
      })
      # => {:ok, %{
      #   symbol: "NASDAQ:TSLA",
      #   oscillators: %{
      #     rsi: 58.32,
      #     stoch_k: 72.15,
      #     stoch_d: 68.40,
      #     cci: 102.50,
      #     adx: 25.80,
      #     macd: 2.15,
      #     macd_signal: 1.80,
      #     momentum: 5.20,
      #     williams_r: -27.85,
      #     bbpower: 3.40,
      #     ultimate_osc: 55.60,
      #     awesome_osc: 8.50
      #   },
      #   moving_averages: %{
      #     ema10: 250.30,
      #     sma10: 249.80,
      #     ...
      #   }
      # }}

      # Get specific indicators only
      IndicatorValues.focus(%{
        symbol: "BTCUSD",
        exchange: "BINANCE",
        screener: "crypto",
        interval: "4h",
        indicators: ["RSI", "MACD.macd", "MACD.signal", "EMA50", "SMA200"]
      })
  """

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  use Lux.Lens,
    name: "TradingView Indicator Values",
    description: "Fetches raw technical indicator values from TradingView scanner API",
    url: "https://scanner.tradingview.com",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
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
          description: "Time interval",
          enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"],
          default: "1d"
        },
        indicators: %{
          type: :array,
          description: "Specific indicator names to fetch (optional, fetches all if omitted)",
          items: %{type: :string}
        }
      },
      required: ["symbol", "exchange"]
    }

  defoverridable focus: 0, focus: 1, focus: 2

  def focus(input \\ %{}, opts \\ [])

  def focus(input, _opts) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    interval = Map.get(input, :interval, "1d")
    requested_indicators = Map.get(input, :indicators, nil)

    ticker = TradingView.format_ticker(symbol, exchange)

    columns =
      if requested_indicators do
        requested_indicators
      else
        TradingView.oscillator_columns() ++ TradingView.moving_average_columns()
      end

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        after_focus(%{
          response: response,
          ticker: ticker,
          columns: columns,
          interval: interval,
          custom_indicators: requested_indicators != nil
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def after_focus(%{
        response: response,
        ticker: ticker,
        columns: columns,
        interval: interval,
        custom_indicators: custom_indicators
      }) do
    interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))
    parsed = Client.parse_scan_response(response, interval_columns)

    case Map.get(parsed, ticker) do
      nil ->
        {:error, "No data returned for #{ticker}"}

      data ->
        if custom_indicators do
          {:ok, %{symbol: ticker, indicators: data}}
        else
          {:ok, %{
            symbol: ticker,
            oscillators: build_oscillators(data),
            moving_averages: build_moving_averages(data)
          }}
        end
    end
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  defp build_oscillators(data) do
    %{
      rsi: data["RSI"],
      rsi_prev: data["RSI[1]"],
      stoch_k: data["Stoch.K"],
      stoch_d: data["Stoch.D"],
      stoch_k_prev: data["Stoch.K[1]"],
      stoch_d_prev: data["Stoch.D[1]"],
      cci: data["CCI20"],
      cci_prev: data["CCI20[1]"],
      adx: data["ADX"],
      adx_plus_di: data["ADX+DI"],
      adx_minus_di: data["ADX-DI"],
      adx_plus_di_prev: data["ADX+DI[1]"],
      adx_minus_di_prev: data["ADX-DI[1]"],
      awesome_osc: data["AO"],
      awesome_osc_prev: data["AO[1]"],
      awesome_osc_prev2: data["AO[2]"],
      momentum: data["Mom"],
      momentum_prev: data["Mom[1]"],
      macd: data["MACD.macd"],
      macd_signal: data["MACD.signal"],
      williams_r: data["W.R"],
      bbpower: data["BBPower"],
      ultimate_osc: data["UO"]
    }
  end

  defp build_moving_averages(data) do
    %{
      ema10: data["EMA10"],
      sma10: data["SMA10"],
      ema20: data["EMA20"],
      sma20: data["SMA20"],
      ema30: data["EMA30"],
      sma30: data["SMA30"],
      ema50: data["EMA50"],
      sma50: data["SMA50"],
      ema100: data["EMA100"],
      sma100: data["SMA100"],
      ema200: data["EMA200"],
      sma200: data["SMA200"],
      ichimoku_baseline: data["Ichimoku.BLine"],
      vwma: data["VWMA"],
      hull_ma9: data["HullMA9"]
    }
  end
end

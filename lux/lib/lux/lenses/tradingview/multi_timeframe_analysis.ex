defmodule Lux.Lenses.TradingView.MultiTimeframeAnalysis do
  @moduledoc """
  Lens for performing multi-timeframe technical analysis from TradingView.

  Fetches technical analysis recommendations across multiple timeframes simultaneously,
  providing a comprehensive view of market sentiment at different time scales.

  ## Example

      alias Lux.Lenses.TradingView.MultiTimeframeAnalysis

      # Analyze Tesla across multiple timeframes
      MultiTimeframeAnalysis.focus(%{
        symbol: "TSLA",
        exchange: "NASDAQ",
        screener: "america",
        intervals: ["15m", "1h", "4h", "1d", "1W"]
      })
      # => {:ok, %{
      #   symbol: "NASDAQ:TSLA",
      #   timeframes: %{
      #     "15m" => %{recommendation: "BUY", value: 0.32, ma: 0.45, oscillators: 0.12},
      #     "1h" => %{recommendation: "NEUTRAL", value: 0.05, ma: 0.15, oscillators: -0.08},
      #     "4h" => %{recommendation: "BUY", value: 0.28, ma: 0.35, oscillators: 0.18},
      #     "1d" => %{recommendation: "STRONG_BUY", value: 0.55, ma: 0.65, oscillators: 0.38},
      #     "1W" => %{recommendation: "BUY", value: 0.42, ma: 0.50, oscillators: 0.30}
      #   },
      #   consensus: "BUY",
      #   alignment: 0.80
      # }}
  """

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  use Lux.Lens,
    name: "TradingView Multi-Timeframe Analysis",
    description: "Fetches technical analysis across multiple timeframes from TradingView",
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
        intervals: %{
          type: :array,
          description: "List of intervals to analyze",
          items: %{
            type: :string,
            enum: ["1m", "5m", "15m", "30m", "1h", "2h", "4h", "1d", "1W", "1M"]
          },
          default: ["1h", "4h", "1d", "1W"]
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
    intervals = Map.get(input, :intervals, ["1h", "4h", "1d", "1W"])

    ticker = TradingView.format_ticker(symbol, exchange)
    base_columns = TradingView.recommendation_columns()

    # Build all columns for all intervals in a single request
    all_columns =
      Enum.flat_map(intervals, fn interval ->
        Enum.map(base_columns, &TradingView.column_with_interval(&1, interval))
      end)

    body = %{
      symbols: %{
        tickers: [ticker],
        query: %{types: []}
      },
      columns: all_columns
    }

    case Client.scan(screener, body) do
      {:ok, response} ->
        after_focus(%{
          response: response,
          ticker: ticker,
          intervals: intervals,
          base_columns: base_columns,
          all_columns: all_columns
        })

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def after_focus(%{
        response: response,
        ticker: ticker,
        intervals: intervals,
        base_columns: _base_columns,
        all_columns: all_columns
      }) do
    # Don't strip interval suffixes so each timeframe's columns remain distinct
    parsed = Client.parse_scan_response(response, all_columns, strip_intervals: false)

    case Map.get(parsed, ticker) do
      nil ->
        {:error, "No data returned for #{ticker}"}

      data ->
        timeframes =
          Map.new(intervals, fn interval ->
            rec_all = data[TradingView.column_with_interval("Recommend.All", interval)]
            rec_ma = data[TradingView.column_with_interval("Recommend.MA", interval)]
            rec_other = data[TradingView.column_with_interval("Recommend.Other", interval)]

            {interval, %{
              recommendation: TradingView.classify_recommendation(rec_all),
              value: rec_all,
              ma: rec_ma,
              oscillators: rec_other
            }}
          end)

        # Calculate consensus (average of all timeframe recommendations)
        all_values =
          timeframes
          |> Map.values()
          |> Enum.map(& &1.value)
          |> Enum.filter(&is_number/1)

        avg_value =
          if Enum.empty?(all_values),
            do: 0,
            else: Enum.sum(all_values) / length(all_values)

        # Calculate alignment (what % of timeframes agree with consensus direction)
        consensus_direction = direction(avg_value)

        alignment =
          if Enum.empty?(all_values) do
            0.0
          else
            agreeing =
              all_values
              |> Enum.count(fn v -> direction(v) == consensus_direction end)

            agreeing / length(all_values)
          end

        {:ok, %{
          symbol: ticker,
          timeframes: timeframes,
          consensus: TradingView.classify_recommendation(avg_value),
          alignment: Float.round(alignment, 2)
        }}
    end
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  defp direction(value) when is_number(value) do
    cond do
      value >= 0.1 -> :bullish
      value <= -0.1 -> :bearish
      true -> :neutral
    end
  end

  defp direction(_), do: :neutral
end

defmodule Lux.Lenses.TradingView.ChartData do
  @moduledoc """
  Lens for fetching chart data (OHLCV and price information) from TradingView.

  Retrieves current price data including open, high, low, close, volume,
  and percentage change for a given symbol.

  ## Example

      alias Lux.Lenses.TradingView.ChartData

      # Get chart data for Tesla
      ChartData.focus(%{
        symbol: "TSLA",
        exchange: "NASDAQ",
        screener: "america",
        interval: "1d"
      })
      # => {:ok, %{
      #   symbol: "NASDAQ:TSLA",
      #   open: 248.50,
      #   high: 255.30,
      #   low: 247.10,
      #   close: 253.80,
      #   volume: 52340000,
      #   change: 2.13,
      #   change_abs: 5.30,
      #   pivot_points: %{
      #     s3: 240.10,
      #     s2: 243.60,
      #     s1: 247.10,
      #     middle: 250.60,
      #     r1: 254.10,
      #     r2: 257.60,
      #     r3: 261.10
      #   }
      # }}
  """

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  use Lux.Lens,
    name: "TradingView Chart Data",
    description: "Fetches OHLCV chart data and pivot points from TradingView scanner API",
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
        include_pivots: %{
          type: :boolean,
          description: "Whether to include pivot point data",
          default: true
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
    include_pivots = Map.get(input, :include_pivots, true)

    ticker = TradingView.format_ticker(symbol, exchange)

    columns =
      TradingView.price_columns() ++
        if(include_pivots, do: TradingView.pivot_columns(), else: [])

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        after_focus(%{
          response: response,
          ticker: ticker,
          columns: columns,
          interval: interval,
          include_pivots: include_pivots
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
        include_pivots: include_pivots
      }) do
    interval_columns = Enum.map(columns, &TradingView.column_with_interval(&1, interval))
    parsed = Client.parse_scan_response(response, interval_columns)

    case Map.get(parsed, ticker) do
      nil ->
        {:error, "No data returned for #{ticker}"}

      data ->
        result = %{
          symbol: ticker,
          open: data["open"],
          high: data["high"],
          low: data["low"],
          close: data["close"],
          volume: data["volume"],
          change: data["change"],
          change_abs: data["change_abs"]
        }

        result =
          if include_pivots do
            Map.put(result, :pivot_points, %{
              s3: data["Pivot.M.Classic.S3"],
              s2: data["Pivot.M.Classic.S2"],
              s1: data["Pivot.M.Classic.S1"],
              middle: data["Pivot.M.Classic.Middle"],
              r1: data["Pivot.M.Classic.R1"],
              r2: data["Pivot.M.Classic.R2"],
              r3: data["Pivot.M.Classic.R3"]
            })
          else
            result
          end

        {:ok, result}
    end
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end
end

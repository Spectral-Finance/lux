defmodule Lux.Lenses.TradingView.TechnicalAnalysis do
  @moduledoc """
  Lens for fetching technical analysis summaries from TradingView.

  Retrieves buy/sell/neutral recommendation counts and overall recommendation
  for oscillators and moving averages, similar to TradingView's Technical Analysis widget.

  ## Example

      alias Lux.Lenses.TradingView.TechnicalAnalysis

      # Get technical analysis for Tesla (daily)
      TechnicalAnalysis.focus(%{
        symbol: "TSLA",
        exchange: "NASDAQ",
        screener: "america",
        interval: "1d"
      })
      # => {:ok, %{
      #   symbol: "NASDAQ:TSLA",
      #   recommendation: "BUY",
      #   summary: %{recommendation: 0.32, buy: 15, sell: 3, neutral: 8},
      #   moving_averages: %{recommendation: 0.45, buy: 10, sell: 2, neutral: 3},
      #   oscillators: %{recommendation: 0.12, buy: 5, sell: 1, neutral: 5}
      # }}

      # Get 4-hour crypto analysis
      TechnicalAnalysis.focus(%{
        symbol: "BTCUSD",
        exchange: "BINANCE",
        screener: "crypto",
        interval: "4h"
      })
  """

  alias Lux.Integrations.TradingView
  alias Lux.Integrations.TradingView.Client

  use Lux.Lens,
    name: "TradingView Technical Analysis",
    description: "Fetches technical analysis summary from TradingView scanner API",
    url: "https://scanner.tradingview.com",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading symbol (e.g., TSLA, BTCUSD, EURUSD)"
        },
        exchange: %{
          type: :string,
          description: "Exchange name (e.g., NASDAQ, BINANCE, FX_IDC)"
        },
        screener: %{
          type: :string,
          description: "Market screener region",
          enum: [
            "america", "crypto", "forex", "cfd", "australia", "brazil",
            "euronext", "germany", "hongkong", "india", "indonesia",
            "japan", "korea", "malaysia", "philippines", "russia",
            "singapore", "spain", "sweden", "taiwan", "thailand",
            "turkey", "uk", "vietnam"
          ],
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
    }

  # Override focus to use our custom TradingView client
  defoverridable focus: 0, focus: 1, focus: 2

  @doc """
  Fetches technical analysis for the given symbol.

  ## Parameters

    * `input` - Map with `:symbol`, `:exchange`, `:screener`, and `:interval`
    * `opts` - Additional options (unused)

  ## Returns

    * `{:ok, analysis}` - Technical analysis summary
    * `{:error, reason}` - Error details
  """
  def focus(input \\ %{}, opts \\ [])

  def focus(input, _opts) do
    symbol = Map.fetch!(input, :symbol)
    exchange = Map.fetch!(input, :exchange)
    screener = Map.get(input, :screener, "america")
    interval = Map.get(input, :interval, "1d")

    ticker = TradingView.format_ticker(symbol, exchange)
    columns = TradingView.recommendation_columns()

    body = Client.build_scan_body([ticker], columns, interval)

    case Client.scan(screener, body) do
      {:ok, response} ->
        after_focus(%{response: response, ticker: ticker, columns: columns, interval: interval})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def after_focus(%{response: response, ticker: ticker, columns: columns, interval: interval}) do
    parsed = Client.parse_scan_response(response, build_interval_columns(columns, interval))

    case Map.get(parsed, ticker) do
      nil ->
        {:error, "No data returned for #{ticker}"}

      data ->
        recommend_all = data["Recommend.All"]
        recommend_ma = data["Recommend.MA"]
        recommend_other = data["Recommend.Other"]

        {:ok, %{
          symbol: ticker,
          recommendation: TradingView.classify_recommendation(recommend_all),
          summary: %{
            recommendation: recommend_all,
            buy: count_signals(recommend_all, recommend_ma, recommend_other, :buy),
            sell: count_signals(recommend_all, recommend_ma, recommend_other, :sell),
            neutral: count_signals(recommend_all, recommend_ma, recommend_other, :neutral)
          },
          moving_averages: %{
            recommendation: recommend_ma,
            computed_signal: TradingView.classify_recommendation(recommend_ma)
          },
          oscillators: %{
            recommendation: recommend_other,
            computed_signal: TradingView.classify_recommendation(recommend_other)
          }
        }}
    end
  end

  def after_focus(response) do
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  defp build_interval_columns(columns, interval) do
    Enum.map(columns, &TradingView.column_with_interval(&1, interval))
  end

  # Estimate signal counts based on recommendation values
  defp count_signals(all, ma, other, :buy) do
    [all, ma, other]
    |> Enum.count(fn val -> is_number(val) and val >= 0.1 end)
  end

  defp count_signals(all, ma, other, :sell) do
    [all, ma, other]
    |> Enum.count(fn val -> is_number(val) and val <= -0.1 end)
  end

  defp count_signals(all, ma, other, :neutral) do
    [all, ma, other]
    |> Enum.count(fn val -> is_number(val) and val > -0.1 and val < 0.1 end)
  end
end

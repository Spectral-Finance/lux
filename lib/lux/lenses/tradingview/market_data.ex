defmodule Lux.Lenses.TradingView.MarketData do
  @moduledoc """
  Market data retrieval lens for TradingView.
  """
  use Lux.Lens,
    name: "TradingView Market Data",
    description: "Fetches OHLCV and ticker data from TradingView",
    url: "https://scanner.tradingview.com/global/scan",
    method: :post,
    headers: [{"content-type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        exchange: %{type: :string},
        symbol: %{type: :string}
      },
      required: ["exchange", "symbol"]
    }

  def before_focus(params) do
    payload = %{
      "symbols" => %{"tickers" => ["#{params[:exchange]}:#{params[:symbol]}"]},
      "columns" => ["open", "high", "low", "close", "volume"]
    }
    {:ok, payload}
  end

  def after_focus({:ok, %{status: 200, body: body}}) do
    case Jason.decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      error -> error
    end
  end
  def after_focus(error), do: error
end

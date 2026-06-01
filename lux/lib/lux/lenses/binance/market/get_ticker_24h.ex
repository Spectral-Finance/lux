defmodule Lux.Lenses.Binance.Market.GetTicker24h do
  @moduledoc """
  A lens for fetching 24-hour rolling window price change statistics from Binance.

  ## Examples

      iex> GetTicker24h.focus(%{symbol: "BTCUSDT"})
      {:ok, %{
        symbol: "BTCUSDT",
        price_change: "-150.00",
        price_change_percent: "-0.300",
        last_price: "49850.00",
        volume: "28350.12",
        high_price: "51000.00",
        low_price: "49200.00"
      }}
  """

  use Lux.Lens,
    name: "Binance 24h Ticker",
    description: "Fetches 24-hour rolling price change statistics from Binance",
    url: "https://api.binance.com/api/v3/ticker/24hr",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol, e.g. BTCUSDT. Omit to get all symbols."
        }
      },
      required: []
    }

  @impl true
  def after_focus(%{"symbol" => _} = ticker) do
    {:ok, parse_ticker(ticker)}
  end

  def after_focus(tickers) when is_list(tickers) do
    {:ok, Enum.map(tickers, &parse_ticker/1)}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, %{code: code, message: msg}}
  end

  defp parse_ticker(t) do
    %{
      symbol: t["symbol"],
      price_change: t["priceChange"],
      price_change_percent: t["priceChangePercent"],
      last_price: t["lastPrice"],
      volume: t["volume"],
      quote_volume: t["quoteVolume"],
      high_price: t["highPrice"],
      low_price: t["lowPrice"],
      open_price: t["openPrice"],
      count: t["count"]
    }
  end
end

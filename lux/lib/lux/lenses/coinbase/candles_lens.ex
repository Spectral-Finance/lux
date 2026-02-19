defmodule Lux.Lenses.Coinbase.CandlesLens do
  @moduledoc """
  A lens for fetching historical candle (OHLCV) data from Coinbase.

  Returns candlestick data for a specific product at various granularities,
  useful for technical analysis and charting.

  ## Supported Granularities

  - `ONE_MINUTE` - 1 minute candles
  - `FIVE_MINUTE` - 5 minute candles
  - `FIFTEEN_MINUTE` - 15 minute candles
  - `THIRTY_MINUTE` - 30 minute candles
  - `ONE_HOUR` - 1 hour candles
  - `TWO_HOUR` - 2 hour candles
  - `SIX_HOUR` - 6 hour candles
  - `ONE_DAY` - 1 day candles

  ## Examples

      iex> Lux.Lenses.Coinbase.CandlesLens.focus(%{
      ...>   product_id: "BTC-USD",
      ...>   start: "1672531200",
      ...>   end: "1672617600",
      ...>   granularity: "ONE_HOUR"
      ...> })
      {:ok, %{candles: [
        %{start: "1672531200", low: "16500.00", high: "16700.00",
          open: "16550.00", close: "16680.00", volume: "123.45"}
      ]}}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Candles",
    description: "Fetches historical candle data from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/products",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Product ID (e.g., BTC-USD)"
        },
        start: %{
          type: :string,
          description: "Start timestamp (Unix epoch seconds)"
        },
        end: %{
          type: :string,
          description: "End timestamp (Unix epoch seconds)"
        },
        granularity: %{
          type: :string,
          description: "Candle granularity",
          enum: [
            "ONE_MINUTE",
            "FIVE_MINUTE",
            "FIFTEEN_MINUTE",
            "THIRTY_MINUTE",
            "ONE_HOUR",
            "TWO_HOUR",
            "SIX_HOUR",
            "ONE_DAY"
          ]
        }
      },
      required: ["product_id", "start", "end", "granularity"]
    }

  def before_focus(%{product_id: product_id} = params) do
    params
    |> Map.delete(:product_id)
    |> Map.put(
      :__url_override__,
      "https://api.coinbase.com/api/v3/brokerage/products/#{product_id}/candles"
    )
  end

  def before_focus(params), do: params

  def after_focus(%{"candles" => candles}) do
    formatted =
      Enum.map(candles, fn candle ->
        %{
          start: candle["start"],
          low: candle["low"],
          high: candle["high"],
          open: candle["open"],
          close: candle["close"],
          volume: candle["volume"]
        }
      end)

    {:ok, %{candles: formatted}}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

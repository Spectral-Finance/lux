defmodule Lux.Lenses.Binance.Market.GetOrderBook do
  @moduledoc """
  A lens for fetching the order book (depth) for a symbol from Binance.

  ## Examples

      iex> GetOrderBook.focus(%{symbol: "BTCUSDT", limit: 5})
      {:ok, %{
        last_update_id: 12345,
        bids: [["50000.00", "1.5"], ...],
        asks: [["50001.00", "0.8"], ...]
      }}
  """

  use Lux.Lens,
    name: "Binance Get Order Book",
    description: "Fetches the order book depth for a symbol from Binance",
    url: "https://api.binance.com/api/v3/depth",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    schema: %{
      type: :object,
      properties: %{
        symbol: %{
          type: :string,
          description: "Trading pair symbol, e.g. BTCUSDT"
        },
        limit: %{
          type: :integer,
          description: "Number of price levels (5, 10, 20, 50, 100, 500, 1000, 5000)",
          default: 100
        }
      },
      required: ["symbol"]
    }

  @impl true
  def after_focus(%{"lastUpdateId" => id, "bids" => bids, "asks" => asks}) do
    {:ok, %{last_update_id: id, bids: bids, asks: asks}}
  end

  def after_focus(%{"code" => code, "msg" => msg}) do
    {:error, %{code: code, message: msg}}
  end
end

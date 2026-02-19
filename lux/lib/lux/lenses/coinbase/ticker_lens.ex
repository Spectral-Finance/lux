defmodule Lux.Lenses.Coinbase.TickerLens do
  @moduledoc """
  A lens for fetching market trades (ticker) data from Coinbase.

  Returns recent market trades for a specific product, useful for
  tracking real-time trading activity.

  ## Examples

      iex> Lux.Lenses.Coinbase.TickerLens.focus(%{product_id: "BTC-USD", limit: 10})
      {:ok, %{
        trades: [
          %{
            trade_id: "123",
            product_id: "BTC-USD",
            price: "43250.00",
            size: "0.001",
            time: "2024-01-01T00:00:00Z",
            side: "BUY"
          }
        ],
        best_bid: "43249.00",
        best_ask: "43251.00"
      }}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Market Trades",
    description: "Fetches market trades for a specific product from Coinbase",
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
        limit: %{
          type: :integer,
          description: "Number of trades to return (max 300)"
        }
      },
      required: ["product_id"]
    }

  def before_focus(%{product_id: product_id} = params) do
    params
    |> Map.delete(:product_id)
    |> Map.put(
      :__url_override__,
      "https://api.coinbase.com/api/v3/brokerage/products/#{product_id}/ticker"
    )
  end

  def before_focus(params), do: params

  def after_focus(%{"trades" => trades} = response) do
    formatted_trades =
      Enum.map(trades, fn trade ->
        %{
          trade_id: trade["trade_id"],
          product_id: trade["product_id"],
          price: trade["price"],
          size: trade["size"],
          time: trade["time"],
          side: trade["side"]
        }
      end)

    {:ok, %{
      trades: formatted_trades,
      best_bid: response["best_bid"],
      best_ask: response["best_ask"]
    }}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

defmodule Lux.Lenses.Coinbase.BestBidAskLens do
  @moduledoc """
  A lens for fetching the best bid/ask prices from Coinbase.

  Returns the current best bid and ask prices for one or more products.

  ## Examples

      iex> Lux.Lenses.Coinbase.BestBidAskLens.focus(%{product_ids: "BTC-USD,ETH-USD"})
      {:ok, %{
        pricebooks: [
          %{
            product_id: "BTC-USD",
            bids: [%{price: "43249.00", size: "1.5"}],
            asks: [%{price: "43251.00", size: "0.8"}]
          }
        ]
      }}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Best Bid/Ask",
    description: "Fetches the best bid/ask prices from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/best_bid_ask",
    method: :get,
    headers: Coinbase.headers(),
    auth: Coinbase.auth(),
    schema: %{
      type: :object,
      properties: %{
        product_ids: %{
          type: :string,
          description: "Comma-separated list of product IDs"
        }
      }
    }

  def after_focus(%{"pricebooks" => pricebooks}) do
    formatted =
      Enum.map(pricebooks, fn book ->
        %{
          product_id: book["product_id"],
          bids:
            Enum.map(book["bids"] || [], fn b -> %{price: b["price"], size: b["size"]} end),
          asks:
            Enum.map(book["asks"] || [], fn a -> %{price: a["price"], size: a["size"]} end),
          time: book["time"]
        }
      end)

    {:ok, %{pricebooks: formatted}}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

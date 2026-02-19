defmodule Lux.Lenses.Coinbase.OrderBookLens do
  @moduledoc """
  A lens for fetching the product order book from Coinbase.

  Returns the current order book (bids and asks) for a specific product.

  ## Examples

      iex> Lux.Lenses.Coinbase.OrderBookLens.focus(%{product_id: "BTC-USD", limit: 10})
      {:ok, %{
        product_id: "BTC-USD",
        bids: [%{price: "43249.00", size: "0.5"}],
        asks: [%{price: "43251.00", size: "0.3"}],
        time: "2024-01-01T00:00:00Z"
      }}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Order Book",
    description: "Fetches the order book for a specific product from Coinbase",
    url: "https://api.coinbase.com/api/v3/brokerage/product_book",
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
          description: "Number of bid/ask levels to return"
        }
      },
      required: ["product_id"]
    }

  def after_focus(%{"pricebook" => pricebook}) do
    bids =
      Enum.map(pricebook["bids"] || [], fn bid ->
        %{price: bid["price"], size: bid["size"]}
      end)

    asks =
      Enum.map(pricebook["asks"] || [], fn ask ->
        %{price: ask["price"], size: ask["size"]}
      end)

    {:ok, %{
      product_id: pricebook["product_id"],
      bids: bids,
      asks: asks,
      time: pricebook["time"]
    }}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

defmodule Lux.Lenses.Coinbase.GetOrderBook do
  @moduledoc """
  A lens for retrieving order book (depth) from Coinbase Advanced Trade.
  """

  use Lux.Lens,
    name: "Coinbase Order Book",
    description: "Fetches market depth for a specific product on Coinbase",
    url: "https://api.coinbase.com/api/v3/brokerage/product_book",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTC-USD)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        },
        limit: %{
          type: :integer,
          description: "Limit of the order book. Default 100",
          default: 100
        }
      },
      required: ["product_id"]
    }

  @impl true
  def before_focus(params, lens) do
    limit = Map.get(params, :limit, 100)
    
    params_for_req = %{
      product_id: String.upcase(params.product_id),
      limit: limit
    }
    
    {:ok, %{lens | params: params_for_req}}
  end

  @impl true
  def after_focus(%{"pricebook" => %{"product_id" => _id, "bids" => bids, "asks" => asks}}) do
    {:ok, %{
      bids: Enum.map(bids, fn b -> %{price: b["price"], quantity: b["size"]} end),
      asks: Enum.map(asks, fn a -> %{price: a["price"], quantity: a["size"]} end)
    }}
  end

  def after_focus(%{"error_response" => %{"message" => message}}) do
    {:error, message}
  end
  
  def after_focus(error), do: {:error, error}
end

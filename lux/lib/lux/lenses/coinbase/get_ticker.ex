defmodule Lux.Lenses.Coinbase.GetTicker do
  @moduledoc """
  A lens for retrieving product/ticker information from Coinbase Advanced Trade.
  """

  use Lux.Lens,
    name: "Coinbase Ticker Data",
    description: "Fetches current ticker price for a specific product on Coinbase",
    url: "https://api.coinbase.com/api/v3/brokerage/products",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        product_id: %{
          type: :string,
          description: "Trading pair symbol (e.g. BTC-USD)",
          pattern: "^[A-Z0-9-_.]{2,}$"
        }
      },
      required: ["product_id"]
    }

  @impl true
  def before_focus(params, lens) do
    product_id = String.upcase(params.product_id)
    url = "https://api.coinbase.com/api/v3/brokerage/products/#{product_id}"

    {:ok, %{lens | url: url, params: %{}}}
  end

  @impl true
  def after_focus(%{"product_id" => product_id, "price" => price}) do
    {:ok, %{
      product_id: product_id,
      price: price
    }}
  end

  def after_focus(%{"error_response" => %{"message" => message}}) do
    {:error, message}
  end
  
  def after_focus(error), do: {:error, error}
end

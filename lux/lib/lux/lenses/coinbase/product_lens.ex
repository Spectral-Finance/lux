defmodule Lux.Lenses.Coinbase.ProductLens do
  @moduledoc """
  A lens for fetching a single product's details from Coinbase.

  Returns detailed information about a specific trading pair including
  price, volume, and trading parameters.

  ## Examples

      iex> Lux.Lenses.Coinbase.ProductLens.focus(%{product_id: "BTC-USD"})
      {:ok, %{
        product_id: "BTC-USD",
        price: "43250.00",
        base_currency_id: "BTC",
        quote_currency_id: "USD",
        status: "online"
      }}
  """

  alias Lux.Integrations.Coinbase

  use Lux.Lens,
    name: "Coinbase Product Detail",
    description: "Fetches details for a specific Coinbase trading product",
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
        }
      },
      required: ["product_id"]
    }

  @doc """
  Adjusts the URL to include the product_id path parameter.
  """
  def before_focus(%{product_id: product_id} = params) do
    Map.delete(params, :product_id)
    |> Map.put(:__url_override__, "https://api.coinbase.com/api/v3/brokerage/products/#{product_id}")
  end

  def before_focus(params), do: params

  @doc """
  Processes the product detail response.
  """
  def after_focus(%{"product_id" => _} = product) do
    {:ok, %{
      product_id: product["product_id"],
      price: product["price"],
      price_percentage_change_24h: product["price_percentage_change_24h"],
      volume_24h: product["volume_24h"],
      base_currency_id: product["base_currency_id"],
      quote_currency_id: product["quote_currency_id"],
      base_min_size: product["base_min_size"],
      base_max_size: product["base_max_size"],
      quote_min_size: product["quote_min_size"],
      quote_max_size: product["quote_max_size"],
      base_increment: product["base_increment"],
      quote_increment: product["quote_increment"],
      product_type: product["product_type"],
      status: product["status"],
      trading_disabled: product["trading_disabled"]
    }}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

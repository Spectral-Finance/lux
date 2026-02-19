defmodule Lux.Lenses.Coinbase.ProductsLens do
  @moduledoc """
  A lens for fetching available products (trading pairs) from Coinbase.

  Returns a list of all available products on Coinbase including
  trading pair details, status, and trading parameters.

  ## Examples

      # List all products
      iex> Lux.Lenses.Coinbase.ProductsLens.focus()
      {:ok, %{products: [%{"product_id" => "BTC-USD", ...}]}}

      # Filter by product type
      iex> Lux.Lenses.Coinbase.ProductsLens.focus(%{product_type: "SPOT"})
      {:ok, %{products: [...]}}
  """

  use Lux.Lens,
    name: "Coinbase Products",
    description: "Fetches available trading products from Coinbase Advanced Trade API",
    url: "https://api.coinbase.com/api/v3/brokerage/products",
    method: :get,
    headers: [{"Content-Type", "application/json"}],
    auth: %{
      type: :custom,
      auth_function: &Lux.Integrations.Coinbase.add_auth_header/1
    },
    schema: %{
      type: :object,
      properties: %{
        product_type: %{
          type: :string,
          description: "Filter by product type (e.g., SPOT, FUTURE)",
          enum: ["SPOT", "FUTURE"]
        },
        product_ids: %{
          type: :string,
          description: "Comma-separated list of product IDs to filter"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of products to return"
        },
        offset: %{
          type: :integer,
          description: "Pagination offset"
        }
      }
    }

  @doc """
  Processes the products API response.
  """
  def after_focus(%{"products" => products}) do
    formatted =
      Enum.map(products, fn product ->
        %{
          product_id: product["product_id"],
          price: product["price"],
          price_percentage_change_24h: product["price_percentage_change_24h"],
          volume_24h: product["volume_24h"],
          volume_percentage_change_24h: product["volume_percentage_change_24h"],
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
        }
      end)

    {:ok, %{products: formatted}}
  end

  def after_focus(%{"error" => error}), do: {:error, error}
  def after_focus(other), do: {:ok, other}
end

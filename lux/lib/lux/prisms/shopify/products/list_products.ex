defmodule Lux.Prisms.Shopify.Products.ListProducts do
  @moduledoc """
  A prism for listing products from the Shopify Admin API.

  ## Examples

      iex> ListProducts.handler(%{limit: 50}, %{name: "Agent"})
      {:ok, %{products: [%{"id" => 1, "title" => "Shirt"}], count: 1}}
  """

  use Lux.Prism,
    name: "List Shopify Products",
    description: "Lists products from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{type: :integer, description: "Max products per page (1-250)"},
        paginate: %{type: :boolean, description: "Fetch all pages"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        products: %{type: :array, description: "The list of products"},
        count: %{type: :integer, description: "Number of products returned"}
      },
      required: ["products"]
    }

  alias Lux.Lenses.Shopify.ListProducts

  def handler(params, _agent) do
    case ListProducts.focus(params) do
      {:ok, products} when is_list(products) ->
        {:ok, %{products: products, count: length(products)}}

      {:ok, products} ->
        {:ok, %{products: products, count: 1}}

      {:error, error} ->
        {:error, error}
    end
  end
end
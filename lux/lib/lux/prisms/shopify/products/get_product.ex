defmodule Lux.Prisms.Shopify.Products.GetProduct do
  @moduledoc """
  A prism for fetching a single product by ID from the Shopify Admin API.

  ## Examples

      iex> GetProduct.handler(%{product_id: 632910392}, %{name: "Agent"})
      {:ok, %{product: %{"id" => 632910392, "title" => "Shirt"}}}
  """

  use Lux.Prism,
    name: "Get Shopify Product",
    description: "Fetches a single product by ID from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :integer, description: "The product ID"}
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        product: %{type: :object, description: "The product"}
      },
      required: ["product"]
    }

  alias Lux.Lenses.Shopify.GetProduct

  def handler(params, _agent) do
    case GetProduct.focus(params) do
      {:ok, product} -> {:ok, %{product: product}}
      {:error, error} -> {:error, error}
    end
  end
end
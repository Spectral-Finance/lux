defmodule Lux.Lenses.Shopify.GetProduct do
  @moduledoc """
  A lens for fetching a single product by ID from the Shopify Admin API.

  ## Examples

      iex> GetProduct.focus(%{product_id: 632910392})
      {:ok, %{"id" => 632910392, "title" => "Shirt"}}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "Get Shopify Product",
    description: "Fetches a single product by ID from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/products",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :integer, description: "The product ID"}
      },
      required: ["product_id"]
    }

  @impl true
  def after_focus(%{"product" => product}), do: {:ok, product}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
end
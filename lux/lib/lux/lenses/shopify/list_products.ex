defmodule Lux.Lenses.Shopify.ListProducts do
  @moduledoc """
  A lens for listing products from the Shopify Admin API.

  Supports cursor-based pagination via the `Link` header. When
  `paginate: true` is passed, all pages are fetched and concatenated.

  ## Examples

      iex> ListProducts.focus(%{})
      {:ok, [%{"id" => 1, "title" => "Shirt"}]}

      iex> ListProducts.focus(%{limit: 50, paginate: true})
      {:ok, [%{"id" => 1}, %{"id" => 2}]}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "List Shopify Products",
    description: "Lists products from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/products.json",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{
        limit: %{type: :integer, description: "Max products per page (1-250)"},
        paginate: %{type: :boolean, description: "Fetch all pages"}
      },
      required: []
    }

  @impl true
  def after_focus(%{"products" => products} = response) do
    {:ok, products, Map.get(response, "next_page")}
  end

  def after_focus(%{"errors" => errors}), do: {:error, errors}
end
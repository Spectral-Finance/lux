defmodule Lux.Lenses.Shopify.ListOrders do
  @moduledoc """
  A lens for listing orders from the Shopify Admin API.

  ## Examples

      iex> ListOrders.focus(%{status: "any"})
      {:ok, [%{"id" => 450789469, "financial_status" => "paid"}]}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "List Shopify Orders",
    description: "Lists orders from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/orders.json",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, description: "Order status filter (any, open, closed, cancelled)"},
        limit: %{type: :integer, description: "Max orders per page (1-250)"}
      },
      required: []
    }

  @impl true
  def after_focus(%{"orders" => orders}), do: {:ok, orders}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
end
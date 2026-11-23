defmodule Lux.Lenses.Shopify.ListCustomers do
  @moduledoc """
  A lens for listing customers from the Shopify Admin API.

  ## Examples

      iex> ListCustomers.focus(%{limit: 50})
      {:ok, [%{"id" => 207119551, "email" => "bob@example.com"}]}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "List Shopify Customers",
    description: "Lists customers from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/customers.json",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{
        limit: %{type: :integer, description: "Max customers per page (1-250)"}
      },
      required: []
    }

  @impl true
  def after_focus(%{"customers" => customers}), do: {:ok, customers}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
end
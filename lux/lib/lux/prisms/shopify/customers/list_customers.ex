defmodule Lux.Prisms.Shopify.Customers.ListCustomers do
  @moduledoc """
  A prism for listing customers from the Shopify Admin API.

  ## Examples

      iex> ListCustomers.handler(%{limit: 50}, %{name: "Agent"})
      {:ok, %{customers: [%{"id" => 207119551}], count: 1}}
  """

  use Lux.Prism,
    name: "List Shopify Customers",
    description: "Lists customers from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{
        limit: %{type: :integer, description: "Max customers per page (1-250)"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        customers: %{type: :array, description: "The list of customers"},
        count: %{type: :integer, description: "Number of customers returned"}
      },
      required: ["customers"]
    }

  alias Lux.Lenses.Shopify.ListCustomers

  def handler(params, _agent) do
    case ListCustomers.focus(params) do
      {:ok, customers} when is_list(customers) ->
        {:ok, %{customers: customers, count: length(customers)}}

      {:ok, customers} ->
        {:ok, %{customers: customers, count: 1}}

      {:error, error} ->
        {:error, error}
    end
  end
end
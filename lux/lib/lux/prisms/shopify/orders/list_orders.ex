defmodule Lux.Prisms.Shopify.Orders.ListOrders do
  @moduledoc """
  A prism for listing orders from the Shopify Admin API.

  ## Examples

      iex> ListOrders.handler(%{status: "any"}, %{name: "Agent"})
      {:ok, %{orders: [%{"id" => 450789469}], count: 1}}
  """

  use Lux.Prism,
    name: "List Shopify Orders",
    description: "Lists orders from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, description: "Order status filter (any, open, closed, cancelled)"},
        limit: %{type: :integer, description: "Max orders per page (1-250)"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        orders: %{type: :array, description: "The list of orders"},
        count: %{type: :integer, description: "Number of orders returned"}
      },
      required: ["orders"]
    }

  alias Lux.Lenses.Shopify.ListOrders

  def handler(params, _agent) do
    case ListOrders.focus(params) do
      {:ok, orders} when is_list(orders) ->
        {:ok, %{orders: orders, count: length(orders)}}

      {:ok, orders} ->
        {:ok, %{orders: orders, count: 1}}

      {:error, error} ->
        {:error, error}
    end
  end
end
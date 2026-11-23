defmodule Lux.Prisms.Shopify.Inventory.ListInventoryLevels do
  @moduledoc """
  A prism for listing inventory levels from the Shopify Admin API.

  ## Examples

      iex> ListInventoryLevels.handler(%{location_ids: "844681632"}, %{name: "Agent"})
      {:ok, %{inventory_levels: [%{"available" => 5}], count: 1}}
  """

  use Lux.Prism,
    name: "List Shopify Inventory Levels",
    description: "Lists inventory levels from the Shopify Admin API",
    input_schema: %{
      type: :object,
      properties: %{
        location_ids: %{type: :string, description: "Comma-separated location IDs"},
        inventory_item_ids: %{type: :string, description: "Comma-separated inventory item IDs"}
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        inventory_levels: %{type: :array, description: "The list of inventory levels"},
        count: %{type: :integer, description: "Number of inventory levels returned"}
      },
      required: ["inventory_levels"]
    }

  alias Lux.Lenses.Shopify.ListInventoryLevels

  def handler(params, _agent) do
    case ListInventoryLevels.focus(params) do
      {:ok, levels} when is_list(levels) ->
        {:ok, %{inventory_levels: levels, count: length(levels)}}

      {:ok, levels} ->
        {:ok, %{inventory_levels: levels, count: 1}}

      {:error, error} ->
        {:error, error}
    end
  end
end
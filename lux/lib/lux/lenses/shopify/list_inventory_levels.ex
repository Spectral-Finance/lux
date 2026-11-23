defmodule Lux.Lenses.Shopify.ListInventoryLevels do
  @moduledoc """
  A lens for listing inventory levels from the Shopify Admin API.

  ## Examples

      iex> ListInventoryLevels.focus(%{location_ids: "844681632"})
      {:ok, [%{"inventory_item_id" => 808950810, "available" => 5}]}
  """

  alias Lux.Integrations.Shopify

  use Lux.Lens,
    name: "List Shopify Inventory Levels",
    description: "Lists inventory levels from the Shopify Admin API",
    url: "#{Shopify.admin_api_url()}/inventory_levels.json",
    method: :get,
    headers: Shopify.headers(),
    auth: Shopify.auth(),
    schema: %{
      type: :object,
      properties: %{
        location_ids: %{type: :string, description: "Comma-separated location IDs"},
        inventory_item_ids: %{type: :string, description: "Comma-separated inventory item IDs"}
      },
      required: []
    }

  @impl true
  def after_focus(%{"inventory_levels" => levels}), do: {:ok, levels}
  def after_focus(%{"errors" => errors}), do: {:error, errors}
end
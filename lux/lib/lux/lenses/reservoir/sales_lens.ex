defmodule Lux.Lenses.Reservoir.SalesLens do
  @moduledoc """
  A lens for fetching NFT sales data from Reservoir.
  """

  alias Lux.Integrations.Reservoir
  require Logger

  use Lux.Lens,
    name: "NFT Sales",
    description: "Fetches recent NFT sales for a collection across marketplaces",
    url: "#{Reservoir.base_url()}/sales/v6",
    method: :get,
    headers: Reservoir.headers(),
    auth: Reservoir.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        },
        limit: %{
          type: :integer,
          description: "Number of sales to fetch"
        }
      },
      required: ["collection"]
    }

  @impl true
  def before_focus(%{collection: collection} = params) do
    limit = Map.get(params, :limit, 10)
    {:ok, %{query: %{collection: collection, limit: limit}}}
  end

  @impl true
  def after_focus(%{"sales" => sales} = _response) do
    Logger.info("Successfully fetched #{length(sales)} sales")
    {:ok, %{sales: Enum.map(sales, &transform_sale/1)}}
  end

  def after_focus(response) do
    Logger.error("Failed to fetch sales: #{inspect(response)}")
    {:error, response}
  end

  defp transform_sale(sale) do
    %{
      id: sale["id"],
      token_id: sale["token"]["tokenId"],
      price: sale["price"]["amount"]["decimal"],
      currency: sale["price"]["currency"]["symbol"],
      marketplace: sale["fillSource"],
      timestamp: sale["timestamp"],
      from: sale["from"],
      to: sale["to"]
    }
  end
end

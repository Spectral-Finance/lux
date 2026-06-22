defmodule Lux.Lenses.Reservoir.MarketTrendsLens do
  @moduledoc """
  A lens for fetching NFT market trends and daily volumes from Reservoir.
  """

  alias Lux.Integrations.Reservoir
  require Logger

  use Lux.Lens,
    name: "NFT Market Trends",
    description: "Fetches daily volume and trend analysis for an NFT collection",
    url: "#{Reservoir.base_url()}/collections/daily-volumes/v1",
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
          description: "Number of days to fetch"
        }
      },
      required: ["collection"]
    }

  @impl true
  def before_focus(%{collection: collection} = params) do
    limit = Map.get(params, :limit, 7)
    {:ok, %{query: %{id: collection, limit: limit}}}
  end

  @impl true
  def after_focus(%{"collections" => [collection_data | _]} = _response) do
    Logger.info("Successfully fetched market trends for #{collection_data["id"]}")
    {:ok, %{trends: collection_data["volumes"] || []}}
  end

  def after_focus(response) do
    Logger.error("Failed to fetch market trends: #{inspect(response)}")
    {:error, response}
  end
end

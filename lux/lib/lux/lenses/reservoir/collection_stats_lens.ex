defmodule Lux.Lenses.Reservoir.CollectionStatsLens do
  @moduledoc """
  A lens for fetching NFT collection statistics from Reservoir.
  """

  alias Lux.Integrations.Reservoir
  require Logger

  use Lux.Lens,
    name: "NFT Collection Stats",
    description: "Fetches collection stats like floor price and volume across marketplaces",
    url: "#{Reservoir.base_url()}/collections/v7",
    method: :get,
    headers: Reservoir.headers(),
    auth: Reservoir.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        }
      },
      required: ["collection"]
    }

  @impl true
  def before_focus(%{collection: collection} = params) do
    {:ok, %{query: %{id: collection}}}
  end

  @impl true
  def after_focus(%{"collections" => [collection_data | _]} = _response) do
    Logger.info("Successfully fetched collection stats for #{collection_data["id"]}")
    {:ok, %{collection_stats: transform_stats(collection_data)}}
  end

  def after_focus(response) do
    Logger.error("Failed to fetch collection stats: #{inspect(response)}")
    {:error, response}
  end

  defp transform_stats(data) do
    %{
      id: data["id"],
      name: data["name"],
      slug: data["slug"],
      token_count: data["tokenCount"],
      owner_count: data["ownerCount"],
      floor_price: data["floorAsk"]["price"]["amount"]["decimal"],
      volume_1d: data["volume"]["1day"],
      volume_all_time: data["volume"]["allTime"]
    }
  end
end

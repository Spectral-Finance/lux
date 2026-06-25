defmodule Lux.Prisms.NFTMarketplace.GetCollectionStats do
  @moduledoc """
  Retrieve collection statistics (floor price, volume, supply, etc.) from an NFT marketplace.
  """

  use Lux.Prism,
    name: "NFT Get Collection Stats",
    description: "Retrieves collection stats from OpenSea, Blur, or X2Y2",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{type: :string, description: "The collection slug (e.g. boredapeyachtclub)"},
        marketplace: %{
          type: :string,
          enum: ["opensea", "blur", "x2y2"],
          default: "opensea",
          description: "Marketplace to query"
        }
      },
      required: ["collection_slug"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string},
        marketplace: %{type: :string},
        floor_price: %{type: :number},
        volume_24h: %{type: :number},
        num_owners: %{type: :integer},
        total_supply: %{type: :integer},
        average_price: %{type: :number}
      },
      required: ["collection", "marketplace", "floor_price"]
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    # Safely fetch parameter keys supporting both string and atom maps
    slug = Map.get(params, "collection_slug") || Map.get(params, :collection_slug)
    mkt = Map.get(params, "marketplace") || Map.get(params, :marketplace) || "opensea"

    if is_nil(slug) or slug == "" do
      {:error, "Missing required parameter: collection_slug"}
    else
      case NFTMarketplace.get_collection_stats(slug, mkt) do
        {:ok, stats} -> {:ok, stats}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

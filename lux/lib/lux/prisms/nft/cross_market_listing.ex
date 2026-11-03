defmodule Lux.Prisms.Nft.CrossMarketListingPrism do
  @moduledoc """
  Compares NFT listings across marketplaces and calculates total buyer cost with fees and royalties.
  """

  use Lux.Prism,
    name: "NFT Cross-Marketplace Listings",
    description: "Evaluates active listings across OpenSea, Blur, and LooksRare to find lowest cost",
    input_schema: %{
      type: :object,
      properties: %{
        listings: %{type: :array, description: "List of listing records from multiple marketplaces"},
        creator_royalty_pct: %{type: :number, default: 5.0}
      },
      required: ["listings"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        best_marketplace: %{type: :string},
        lowest_total_cost_eth: %{type: :number},
        listings: %{type: :array}
      },
      required: ["best_marketplace", "lowest_total_cost_eth"]
    }

  alias Lux.Nft.CrossMarketplace

  def handler(input, _ctx) do
    listings = Map.get(input, :listings) || Map.get(input, "listings", [])
    royalty = (Map.get(input, :creator_royalty_pct) || Map.get(input, "creator_royalty_pct", 5.0)) * 1.0

    result = CrossMarketplace.compare_listings(listings, royalty)

    {:ok,
     %{
       best_marketplace: to_string(result.best_marketplace),
       lowest_total_cost_eth: result.lowest_total_cost_eth,
       listings: result.listings
     }}
  end
end

defmodule Lux.Beams.Nft.NftAggregationBeam do
  @moduledoc """
  A coordinated workflow beam for multi-marketplace NFT analytics:
  1. Gathers and normalizes collection statistics via CollectionStatsPrism
  2. Compares floor prices across OpenSea, Blur, and LooksRare via FloorPricePrism
  3. Evaluates active listings and net buyer acquisition cost via CrossMarketListingPrism
  """

  use Lux.Beam,
    name: "NFT Marketplace Aggregation Beam",
    description: "Evaluates collection statistics, compares multi-market floor prices, and finds best listing routes",
    input_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string, description: "Collection slug or address"},
        stats_data: %{type: :object, description: "Raw stats payload"},
        opensea_floor: %{type: :number},
        blur_floor: %{type: :number},
        looksrare_floor: %{type: :number},
        listings: %{type: :array, default: []}
      },
      required: ["collection", "stats_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        collection_stats: %{type: :object},
        floor_comparison: %{type: :object},
        best_listing: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Nft.CollectionStatsPrism
  alias Lux.Prisms.Nft.FloorPricePrism
  alias Lux.Prisms.Nft.CrossMarketListingPrism

  sequence do
    step(:collection_stats, CollectionStatsPrism, %{
      collection: [:input, :collection],
      stats_data: [:input, :stats_data]
    })

    step(:floor_comparison, FloorPricePrism, %{
      collection: [:input, :collection],
      opensea_floor: [:input, :opensea_floor],
      blur_floor: [:input, :blur_floor],
      looksrare_floor: [:input, :looksrare_floor]
    })

    step(:best_listing, CrossMarketListingPrism, %{
      listings: [:input, :listings]
    })
  end
end

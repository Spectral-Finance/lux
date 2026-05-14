defmodule Lux.Prisms.NFT.MarketplaceAggregationPrism do
  @moduledoc """
  Prism wrapper for NFT marketplace data aggregation.
  """

  use Lux.Prism,
    name: "NFT Marketplace Aggregation",
    description:
      "Aggregates NFT collection, listing, sale, rarity, trait, and trend data across marketplaces",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{type: :string, description: "Collection slug used by marketplaces"},
        contract_address: %{type: :string, description: "Collection contract address"},
        chain: %{type: :string, description: "Chain identifier"},
        marketplaces: %{
          type: :array,
          description: "Marketplace names or marketplace data payloads"
        },
        tokens: %{
          type: :array,
          description: "Optional collection tokens with trait metadata"
        }
      },
      required: ["collection_slug", "marketplaces"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection_data: %{type: :object},
        price_tracking: %{type: :object},
        sales_monitoring: %{type: :object},
        rarity: %{type: :object},
        trait_analysis: %{type: :object},
        market_trends: %{type: :object},
        listing_management: %{type: :object},
        cross_marketplace_comparison: %{type: :object}
      },
      required: [
        "collection_data",
        "price_tracking",
        "sales_monitoring",
        "rarity",
        "trait_analysis",
        "market_trends",
        "cross_marketplace_comparison"
      ]
    }

  alias Lux.Integrations.NFT.MarketplaceAggregator

  @impl true
  def handler(input, _context) when is_map(input) do
    {:ok, MarketplaceAggregator.aggregate(input)}
  end
end

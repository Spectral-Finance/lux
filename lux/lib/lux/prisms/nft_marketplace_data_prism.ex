defmodule Lux.Prisms.NftMarketplaceDataPrism do
  @moduledoc """
  A prism that aggregates NFT marketplace data for a specific collection.
  Uses multiple lenses (Stats, Sales, Market Trends, Rarity) to provide a comprehensive analysis.

  ## Examples

  ```elixir
  alias Lux.Prisms.NftMarketplaceDataPrism

  NftMarketplaceDataPrism.run(%{
    collection: "0x8d04a8c79ceb0889bdd12acdf3fa9d207ed3ff63"
  })
  ```
  """

  use Lux.Prism,
    name: "NFT Marketplace Data Aggregation",
    description: "Aggregates stats, sales, and market trends for an NFT collection",
    input_schema: %{
      type: :object,
      properties: %{
        collection: %{
          type: :string,
          description: "Collection contract address"
        }
      },
      required: ["collection"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        stats: %{
          type: :object,
          description: "Collection statistics"
        },
        recent_sales: %{
          type: :array,
          description: "Recent sales across marketplaces"
        },
        trends: %{
          type: :array,
          description: "Daily market volume trends"
        },
        rarity_analysis: %{
          type: :array,
          description: "Top tokens sorted by rarity"
        }
      },
      required: ["stats", "recent_sales", "trends", "rarity_analysis"]
    }

  alias Lux.Lenses.Reservoir.{CollectionStatsLens, SalesLens, MarketTrendsLens, RarityLens}
  require Logger

  def handler(%{collection: collection}, _ctx) do
    Logger.info("Aggregating NFT marketplace data for collection: #{collection}")

    with {:ok, %{collection_stats: stats}} <- CollectionStatsLens.focus(%{collection: collection}),
         {:ok, %{sales: sales}} <- SalesLens.focus(%{collection: collection, limit: 10}),
         {:ok, %{trends: trends}} <- MarketTrendsLens.focus(%{collection: collection, limit: 7}),
         {:ok, %{tokens: rarity}} <- RarityLens.focus(%{collection: collection, limit: 5}) do
      
      {:ok, %{
        stats: stats,
        recent_sales: sales,
        trends: trends,
        rarity_analysis: rarity
      }}
    else
      {:error, reason} ->
        Logger.error("Failed to aggregate NFT data: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

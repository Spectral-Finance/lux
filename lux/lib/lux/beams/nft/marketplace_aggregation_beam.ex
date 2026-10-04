defmodule Lux.Beams.NFT.MarketplaceAggregationBeam do
  @moduledoc """
  A workflow Beam that orchestrates end-to-end multi-marketplace data aggregation:
  1. Queries cross-marketplace floor prices (OpenSea, Blur, LooksRare)
  2. Ingests and normalizes recent sales events
  3. Executes price tracking and technical trend analysis
  4. Emits actionable NFT market intelligence

  ## Example

      Lux.Beams.NFT.MarketplaceAggregationBeam.run(%{
        collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
      })
  """

  use Lux.Beam,
    name: "NFT Multi-Marketplace Aggregation Workflow",
    description: "End-to-end multi-venue floor pricing, sales ingestion, and trend analytics",
    input_schema: %{
      type: :object,
      properties: %{
        collection_address: %{
          type: :string,
          description: "Contract address of the NFT collection"
        }
      },
      required: ["collection_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        floor_data: %{type: :object},
        sales_data: %{type: :object},
        trend_analysis: %{type: :object}
      },
      required: ["floor_data", "sales_data", "trend_analysis"]
    },
    generate_execution_log: true

  alias Lux.Prisms.NFT.MultiMarketplaceConnectorPrism
  alias Lux.Prisms.NFT.PriceTrackingPrism
  alias Lux.Prisms.NFT.SalesStreamPollerPrism

  sequence do
    # Step 1: Query multi-marketplace floor prices
    step(:floor_data, MultiMarketplaceConnectorPrism, %{
      collection_address: [:input, :collection_address]
    })

    # Step 2: Poll and normalize recent sales
    step(:sales_data, SalesStreamPollerPrism, %{
      collection_address: [:input, :collection_address],
      limit: 30
    })

    # Step 3: Compute price tracking metrics & trend analysis
    step(:trend_analysis, PriceTrackingPrism, %{
      collection_address: [:input, :collection_address],
      current_floor_eth: [:steps, :floor_data, :result, :best_floor_price_eth],
      sales: [:steps, :sales_data, :result, :sales]
    })
  end
end

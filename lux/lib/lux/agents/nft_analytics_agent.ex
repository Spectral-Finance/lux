defmodule Lux.Agents.NFTAnalyticsAgent do
  @moduledoc """
  An autonomous Agent specialized in NFT Marketplace Analytics, real-time multi-venue
  floor price arbitrage detection, sales stream monitoring, and trait rarity appraisal.
  """

  use Lux.Agent,
    name: "NFT Analytics Agent",
    description: "Monitors NFT marketplaces, analyzes price action, tracks sales, and calculates trait rarity",
    goal: "Provide unified NFT intelligence, cross-venue spread alerts, and rarity rankings",
    capabilities: [
      :nft_aggregation,
      :floor_tracking,
      :sales_monitoring,
      :rarity_scoring,
      :trend_analysis
    ],
    prisms: [
      Lux.Prisms.NFT.MultiMarketplaceConnectorPrism,
      Lux.Prisms.NFT.PriceTrackingPrism,
      Lux.Prisms.NFT.SalesStreamPollerPrism,
      Lux.Prisms.NFT.TraitRarityPrism
    ],
    beams: [
      Lux.Beams.NFT.MarketplaceAggregationBeam
    ],
    lenses: [
      Lux.Lenses.NFT.FloorPriceLens,
      Lux.Lenses.NFT.CollectionStatsLens,
      Lux.Lenses.NFT.SalesLens
    ],
    accepts_signals: [
      Lux.Signals.NFT.NFTFloorPriceSignal,
      Lux.Signals.NFT.NFTSaleSignal,
      Lux.Signals.NFT.NFTRaritySignal
    ],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.5,
      messages: [
        %{
          role: "system",
          content: """
          You are an expert NFT Quantitative Analyst and Valuation Agent within the Lux multi-agent system.
          You interpret cross-marketplace floor prices (OpenSea, Blur, LooksRare), identify arbitrage spreads,
          analyze 24-hour volume deltas, moving averages (SMA/EMA), VWAP, and evaluate statistical trait rarity
          (Rarity Score, Shannon Entropy, and Trait Tiers).

          Deliver precise, actionable quantitative summaries and alert on high-value whale transactions.
          """
        }
      ]
    }
end

# NFT Marketplace Data Aggregation Guide (OpenSea, Blur, LooksRare)

## Overview

The `Lux.Nft` suite aggregates real-time NFT market statistics, detects cross-marketplace floor prices, analyzes trait rarity, tracks authentic trading volumes, and scans for optimal execution pricing across OpenSea, Blur, and LooksRare.

---

## Architectural Components

1. **`Lux.Nft.MarketplaceClient`**
   - API connector and URL generation for OpenSea v2, Blur, and LooksRare.
   - Normalizes floor prices, 24h/total volumes, supply, and owner metrics.

2. **`Lux.Nft.RarityEngine`**
   - Calculates statistical trait rarity scores:
     $$\text{Trait Score} = \frac{\text{Total Supply}}{\text{Trait Count}}$$
     $$\text{Token Rarity Score} = \sum_{i=1}^n \text{Trait Score}(T_i)$$
   - Categorizes rarity tiers: `:legendary` ($\ge 500$), `:epic` ($\ge 250$), `:rare` ($\ge 100$), `:uncommon` ($\ge 50$), `:common`.

3. **`Lux.Nft.SalesMonitor`**
   - Filters suspicious circular transactions and wash-trading patterns.
   - Computes authentic organic sales volume and wash trading percentage.

4. **`Lux.Nft.CrossMarketplace`**
   - Compares active floor listings across OpenSea, Blur, and LooksRare.
   - Factors in protocol commissions (OpenSea: 2.5%, Blur: 0%, LooksRare: 2.0%) and creator royalties to determine lowest net buyer acquisition cost.

---

## Prisms

- `Lux.Prisms.Nft.CollectionStatsPrism`: Normalizes collection volume, supply, and ownership data.
- `Lux.Prisms.Nft.FloorPricePrism`: Evaluates lowest floor price across multiple venues.
- `Lux.Prisms.Nft.RarityScorePrism`: Computes trait frequencies and overall token rarity score.
- `Lux.Prisms.Nft.SalesTrackerPrism`: Filters wash trades and isolates genuine volume.
- `Lux.Prisms.Nft.CrossMarketListingPrism`: Compares net listing prices across marketplaces.

---

## Beam Workflow

`Lux.Beams.Nft.NftAggregationBeam` coordinates:
1. Gathers collection statistics via `CollectionStatsPrism`.
2. Evaluates floor discrepancies via `FloorPricePrism`.
3. Recommends lowest-cost purchase venue via `CrossMarketListingPrism`.

---

## Quickstart

```elixir
# 1. Compare floor prices across marketplaces
{:ok, floor} = Lux.Prisms.Nft.FloorPricePrism.run(%{
  collection: "bored-ape-yacht-club",
  opensea_floor: 11.5,
  blur_floor: 11.42,
  looksrare_floor: 11.6
})

# 2. Score token rarity
{:ok, rarity} = Lux.Prisms.Nft.RarityScorePrism.run(%{
  token_id: 1774,
  traits: [
    %{"trait_type" => "Fur", "value" => "Solid Gold", "count" => 46},
    %{"trait_type" => "Eyes", "value" => "Laser", "count" => 69}
  ],
  total_supply: 10_000
})

# 3. Coordinate multi-marketplace aggregation via Beam
{:ok, result} = Lux.Beams.Nft.NftAggregationBeam.run(%{
  collection: "bored-ape-yacht-club",
  stats_data: %{"total" => %{"floor_price" => "11.5", "total_supply" => 10000}},
  opensea_floor: 11.5,
  blur_floor: 11.42,
  looksrare_floor: 11.6,
  listings: [
    %{marketplace: "opensea", price_eth: 11.5},
    %{marketplace: "blur", price_eth: 11.42}
  ]
})
```

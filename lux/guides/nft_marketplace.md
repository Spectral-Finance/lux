# NFT Marketplace Data Aggregation

Lux provides a robust NFT Marketplace Data Aggregation system, primarily powered by the Reservoir integration. It supports major platforms including OpenSea, Blur, X2Y2, and others.

## Core Features
- **Collection statistics**: Floor price, token count, ownership details.
- **Price tracking**: Track floor prices and sales.
- **Sales monitoring**: Real-time recent sales across marketplaces.
- **Rarity calculation**: Token rarity scoring and ranking.
- **Market trends**: Daily volume and overall trend analysis.
- **Cross-marketplace comparison**: Unified data model irrespective of origin.

## Setup

First, configure your API keys in your `config/runtime.exs` or `dev.envrc`:

```elixir
config :lux, :api_keys,
  reservoir: System.get_env("RESERVOIR_API_KEY")
```

## Lenses

You can fetch specific NFT marketplace data using our specialized lenses.

### Collection Stats

```elixir
alias Lux.Lenses.Reservoir.CollectionStatsLens

{:ok, %{collection_stats: stats}} = CollectionStatsLens.focus(%{
  collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
})
IO.inspect(stats.floor_price)
```

### Sales Monitoring

```elixir
alias Lux.Lenses.Reservoir.SalesLens

{:ok, %{sales: recent_sales}} = SalesLens.focus(%{
  collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
  limit: 10
})
```

### Market Trends

```elixir
alias Lux.Lenses.Reservoir.MarketTrendsLens

{:ok, %{trends: trends}} = MarketTrendsLens.focus(%{
  collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
  limit: 7
})
```

### Rarity Analysis

```elixir
alias Lux.Lenses.Reservoir.RarityLens

{:ok, %{tokens: tokens}} = RarityLens.focus(%{
  collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
  limit: 5
})
```

## Prism

If you need a comprehensive overview of a collection all at once, you can use the `NftMarketplaceDataPrism` to aggregate everything automatically.

```elixir
alias Lux.Prisms.NftMarketplaceDataPrism

{:ok, aggregated_data} = NftMarketplaceDataPrism.run(%{
  collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
})

# Access stats, sales, trends, and rarity
IO.inspect(aggregated_data.stats)
IO.inspect(aggregated_data.recent_sales)
```

# NFT Marketplace Aggregation

`Lux.Integrations.Nft.Marketplace` provides the deterministic aggregation core for
NFT marketplace data. Marketplace-specific lenses can fetch OpenSea, Blur, X2Y2,
or other API payloads and pass simple maps into this module.

The module covers:

- collection statistics across marketplaces
- active listing price tracking and floor comparison
- sales monitoring with collection, marketplace, price, and time filters
- trait-frequency rarity scoring and ranking
- daily, hourly, or weekly market trend buckets
- a combined cross-marketplace analytics report

## Example

```elixir
alias Lux.Integrations.Nft.Marketplace

report =
  Marketplace.cross_marketplace_report(%{
    collections: [
      %{marketplace: "OpenSea", slug: "azuki", floor_price: 4.2, volume: 1200, owners: 4300},
      %{marketplace: "Blur", slug: "azuki", floor_price: 4.0, volume: 950, owners: 4100}
    ],
    listings: [
      %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 4.2},
      %{marketplace: "Blur", collection: "azuki", token_id: 2, price: 4.0}
    ],
    sales: [
      %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 4.1, timestamp: "2026-05-11T10:00:00Z"},
      %{marketplace: "Blur", collection: "azuki", token_id: 2, price: 4.0, timestamp: "2026-05-12T09:00:00Z"}
    ],
    tokens: [
      %{token_id: 1, traits: %{background: "red", eyes: "laser"}},
      %{token_id: 2, traits: %{background: "red", eyes: "normal"}}
    ]
  })

report.collection.floor_price
#=> 4.0

report.prices.by_marketplace["blur"].floor_price
#=> 4.0

hd(report.rarity.tokens).rarity_rank
#=> 1
```

## Data shape

Input maps can use atom or string keys. Numeric fields may be numbers or numeric
strings.

The aggregation layer is intentionally side-effect free. It accepts payloads
that marketplace lenses have already fetched and normalizes them without live
API calls, wallet actions, listing or bid creation, or API credentials.

Collection fields:

- `marketplace`
- `slug`, `collection`, or `name`
- `floor_price` or `floor`
- `volume` or `total_volume`
- `owners` or `owner_count`
- `supply` or `total_supply`

Listing fields:

- `marketplace`
- `collection` or `slug`
- `token_id` or `id`
- `price` or `amount`
- `currency`
- `seller`
- `url`
- `status`

Only active listings with positive numeric prices are included in price
summaries. Cancelled, inactive, zero, negative, and non-numeric listings are
ignored for floor, average, median, and cheapest-listing selection.

Sale fields:

- `marketplace`
- `collection` or `slug`
- `token_id` or `id`
- `price` or `amount`
- `currency`
- `buyer`
- `seller`
- `timestamp` or `sold_at`

Sales without timestamps remain valid for sales monitoring and are grouped into
an `unknown` trend bucket.

Token rarity fields:

- `token_id` or `id`
- `collection` or `slug`
- `name`
- `traits` as either `%{trait_type => value}` or a list of trait maps

## Rarity model

Rarity scoring uses inverse trait frequency:

```text
score = sum(collection_supply / trait_value_frequency)
```

Tokens are sorted from highest score to lowest score. Higher scores represent
rarer trait combinations.

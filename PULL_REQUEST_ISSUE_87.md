# Pull Request: NFT Marketplace Data Aggregation Suite

**Fixes #87** ($750 Bounty)

## Summary of Changes

This PR delivers a production-grade, multi-venue **NFT Marketplace Data Aggregation and Analytics Suite** for the Lux multi-agent framework.

It introduces a resilient integration supporting **OpenSea**, **Blur**, and **LooksRare**, featuring real-time floor price aggregation, quantitative price tracking, event-normalized sales monitoring streams, and a statistical trait rarity calculation engine.

---

## Key Modules & Features Implemented

### 1. Multi-Marketplace Connector (`lux.nft.connectors`)
- **Connectors**:
  - `OpenSeaConnector`: OpenSea API v2 endpoints for collections, stats, events, and token metadata.
  - `BlurConnector`: Blur feeds for real-time floor quotes, volume intervals, and activity streams with 0% marketplace fee modeling.
  - `LooksRareConnector`: LooksRare API v2 endpoints for protocol order books, floor price metrics, and verified sale events.
- **Resilience Engine**:
  - `TokenBucketRateLimiter`: Thread-safe token bucket algorithm with configurable RPS and burst capacity.
  - `CircuitBreaker`: Prevents cascading network failures with state transitions (`CLOSED`, `OPEN`, `HALF_OPEN`).
  - `RetryConfig`: Exponential backoff with random jitter on retryable HTTP errors (429, 500, 502, 503, 504).
  - `MultiMarketplaceAggregator`: Concurrent multi-venue querying with automatic failover and graceful degradation.

### 2. Price Tracking Engine (`lux.nft.pricing`)
- **Floor Price & Spread Tracking**: Compares cross-marketplace floor prices, determines best marketplace, and calculates absolute ETH & percentage price spreads.
- **Volume Metrics**: Computes 1h, 24h, 7d, 30d, and total volume across all venues.
- **24-Hour Percentage Deltas**: Tracks 24h floor price % change, volume % change, and average price % change.
- **Technical & Quantitative Analytics**:
  - Simple Moving Averages (`SMA_7`, `SMA_24`, `SMA_30`)
  - Exponential Moving Averages (`EMA_7`, `EMA_24`) with smoothing factor $\alpha = \frac{2}{N+1}$
  - Volume-Weighted Average Price (`VWAP`)
  - Price Volatility estimation via log returns standard deviation
  - Outlier filtering via Interquartile Range (IQR) rejection
  - Trend direction classification (`BULLISH`, `BEARISH`, `BREAKOUT`, `DUMPING`, `NEUTRAL`)

### 3. Sales Monitoring Stream & Normalizer (`lux.nft.sales`)
- **Canonical Event Schema**: Standardizes heterogeneous marketplace events into `SaleEvent`.
- **Event Deduplicator**: LRU + TTL sliding window cache guaranteeing idempotency across overlapping polling feeds.
- **Replay Buffer**: In-memory ring buffer with multi-attribute filtering (price range, token ID, timestamp).
- **Sales Stream Poller**: Batch and continuous poller with whale transaction detection and event subscriber dispatching.

### 4. Trait Rarity Scoring Engine (`lux.nft.rarity`)
- **Trait Frequency Normalization**: Calculates exact frequencies across collection supply.
- **Missing Trait Handling**: Explicitly evaluates missing traits as `None` with normalized frequencies.
- **Trait Count Property**: Evaluates total trait count per token as a distinct rarity feature.
- **Multiple Scoring Methods**:
  - **Rarity Score**: $\sum \frac{1}{P(\text{trait})}$ (RarityTools Standard)
  - **Information Entropy**: $\sum -\log_2(P(\text{trait}))$ (Shannon Surprisal in bits)
  - **Statistical Joint Probability**: $\prod P(\text{trait})$ (Log10 scale)
  - **Harmonic Mean Score**: $\frac{K}{\sum P(\text{trait})}$
- **Collection Indexing**: Computes token rankings (#1 to #N), percentile ranks, rarest trait per token, and rarity tier assignments (`Legendary`, `Epic`, `Rare`, `Uncommon`, `Common`).

### 5. Lux Elixir Integration Layer (`lux/lib/lux/`)
- `Lux.Integrations.NFTMarketplaces`: Central configuration and authentication header manager.
- `Lux.Lenses.NFT.*`: Lenses for `FloorPriceLens`, `CollectionStatsLens`, and `SalesLens`.
- `Lux.Prisms.NFT.*`: Prisms for `MultiMarketplaceConnectorPrism`, `PriceTrackingPrism`, `SalesStreamPollerPrism`, and `TraitRarityPrism`.
- `Lux.Beams.NFT.MarketplaceAggregationBeam`: Orchestrated end-to-end multi-marketplace data pipeline.
- `Lux.Signals.NFT.*`: Type-safe Signal schemas (`NFTFloorPriceSignal`, `NFTSaleSignal`, `NFTRaritySignal`).
- `Lux.Agents.NFTAnalyticsAgent`: Autonomous multi-agent specialized in NFT intelligence and whale transaction alerting.

---

## File Structure

```
lux/
├── lib/lux/
│   ├── integrations/
│   │   └── nft_marketplaces.ex
│   ├── lenses/
│   │   └── nft/
│   │       ├── floor_price_lens.ex
│   │       ├── collection_stats_lens.ex
│   │       └── sales_lens.ex
│   ├── prisms/
│   │   └── nft/
│   │       ├── multi_marketplace_connector_prism.ex
│   │       ├── price_tracking_prism.ex
│   │       ├── sales_stream_poller_prism.ex
│   │       └── trait_rarity_prism.ex
│   ├── beams/
│   │   └── nft/
│   │       └── marketplace_aggregation_beam.ex
│   ├── signals/
│   │   └── nft/
│   │       ├── nft_floor_price_signal.ex
│   │       ├── nft_sale_signal.ex
│   │       └── nft_rarity_signal.ex
│   └── agents/
│       └── nft_analytics_agent.ex
├── priv/python/
│   ├── lux/
│   │   └── nft/
│   │       ├── __init__.py
│   │       ├── types.py
│   │       ├── pipeline.py
│   │       ├── connectors/
│   │       │   ├── __init__.py
│   │       │   ├── base.py
│   │       │   ├── opensea.py
│   │       │   ├── blur.py
│   │       │   ├── looksrare.py
│   │       │   └── aggregator.py
│   │       ├── pricing/
│   │       │   ├── __init__.py
│   │       │   └── engine.py
│   │       ├── sales/
│   │       │   ├── __init__.py
│   │       │   ├── dedup.py
│   │       │   ├── normalizer.py
│   │       │   └── poller.py
│   │       └── rarity/
│   │           ├── __init__.py
│   │           ├── scoring.py
│   │           └── engine.py
│   └── tests/
│       └── nft/
│           ├── test_connectors.py
│           ├── test_pricing_engine.py
│           ├── test_sales_poller.py
│           ├── test_rarity_engine.py
│           ├── test_pipeline.py
│           └── test_edge_cases.py
└── docs/
    └── nft_marketplace_aggregation.md
```

---

## Verification & Testing

All test suites were executed with 100% pass rate:

```bash
cd lux/priv/python
python -m pytest
```

**Results:**
```
============================= 49 passed in 9.16s ==============================
```

- **Unit tests**: Rate limiter token refill, circuit breaker tripping & recovery, connector request serialization, header generation.
- **Pricing tests**: Outlier filtering via IQR, VWAP weighting, moving averages (SMA/EMA), volatility, trend classification.
- **Sales tests**: Event normalization, deduplication cache eviction & idempotency, whale alerting, buffer querying.
- **Rarity tests**: Rarity score, Shannon entropy, statistical probability product, harmonic mean, missing traits handling, ranking, tier classification.
- **Integration tests**: Multi-marketplace cross-venue spread calculations, pipeline end-to-end aggregation report generation.

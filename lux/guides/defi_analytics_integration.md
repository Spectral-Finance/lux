# DeFi Analytics Integration Guide (DeFiLlama & Dune Analytics)

## Overview

The `Lux.Analytics.Defi` framework integrates on-chain data from DeFiLlama and Dune Analytics. It enables real-time protocol TVL monitoring, multi-chain volume tracking, yield opportunity filtering, SQL query orchestration, and automated anomaly alert triggers.

---

## Architecture Components

1. **`Lux.Analytics.Defi.DefiLlama`**
   - Protocol TVL, current chain allocations, and 24h change monitoring.
   - DEX volume aggregation across multiple chains.
   - Yield pool filtering by token, blockchain, minimum TVL, and APY boundaries.

2. **`Lux.Analytics.Defi.Dune`**
   - Connects to Dune Analytics API v1 (`https://api.dune.com/api/v1`).
   - Handles SQL query parameterization, asynchronous execution dispatch, status tracking, and structured column/row parsing.

3. **`Lux.Analytics.Defi.AlertEngine`**
   - Detects abnormal protocol anomalies:
     - **TVL Shock:** Triggered when 24h TVL drops $\ge 10\%$ (warning) or $\ge 25\%$ (critical).
     - **Stablecoin Depeg:** Triggered when peg variance $\ge 1.0\%$ (warning) or $\ge 5.0\%$ (critical).
     - **Yield Anomaly:** Triggered when pool APY spikes beyond realistic ranges ($\ge 200\%$) or collapses to $0\%$.

4. **`Lux.Analytics.Defi.Dashboard`**
   - Generates formatted ASCII multi-chain TVL summary tables and yield opportunity leaderboards.

---

## Prisms

- `Lux.Prisms.Analytics.Defi.ProtocolTvlPrism`: Formats and structures protocol TVL and chain distributions.
- `Lux.Prisms.Analytics.Defi.YieldPoolsPrism`: Filters and screens yield pools according to risk/reward parameters.
- `Lux.Prisms.Analytics.Defi.DexVolumePrism`: Analyzes 24h DEX volumes and top exchange market share.
- `Lux.Prisms.Analytics.Defi.DuneQueryPrism`: Dispatches and parses parameterized Dune SQL queries.
- `Lux.Prisms.Analytics.Defi.DeFiAlertsPrism`: Generates security alerts for drawdowns and depeg conditions.

---

## Beam Workflow

`Lux.Beams.Analytics.Defi.DefiAnalyticsBeam` coordinates:
1. Normalizes TVL data using `ProtocolTvlPrism`.
2. Evaluates drawdown risk with `DeFiAlertsPrism`.
3. Discovers and ranks yield farms via `YieldPoolsPrism`.

---

## Quickstart

```elixir
# 1. Parse protocol TVL metrics
{:ok, tvl} = Lux.Prisms.Analytics.Defi.ProtocolTvlPrism.run(%{
  protocol_data: %{
    "name" => "Aave V3",
    "tvl" => "12500000000.0",
    "change_1d" => "-1.2"
  }
})

# 2. Check for security alerts
{:ok, alerts} = Lux.Prisms.Analytics.Defi.DeFiAlertsPrism.run(%{
  protocol: "Aave V3",
  change_1d_pct: -1.2
})

# 3. Coordinate workflow with DefiAnalyticsBeam
{:ok, result} = Lux.Beams.Analytics.Defi.DefiAnalyticsBeam.run(%{
  protocol: "Aave V3",
  protocol_data: %{
    "name" => "Aave V3",
    "tvl" => "12500000000.0",
    "change_1d" => "-1.2"
  },
  pools: []
})
```

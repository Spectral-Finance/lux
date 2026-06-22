# DeFi Analytics Integration

Lux provides comprehensive DeFi analytics integrations through DeFiLlama and Dune Analytics. This allows agents to seamlessly interact with blockchain data, track TVL, monitor yields, and perform custom data analysis.

## DeFiLlama Lenses

DeFiLlama provides public APIs without requiring authentication. The following lenses are available:

- `Lux.Lenses.DefiLlama.GetTvl`: Fetches historical TVL (Total Value Locked) across all chains.
- `Lux.Lenses.DefiLlama.GetProtocols`: Fetches the current list of protocols and their current TVL metrics.
- `Lux.Lenses.DefiLlama.GetYields`: Fetches yield pools and APY metrics.
- `Lux.Lenses.DefiLlama.GetVolumes`: Fetches daily DEX volumes.

### Example: Finding Best Yields

```elixir
{:ok, pools} = Lux.Lenses.DefiLlama.GetYields.focus()
best_pools = Enum.take(pools, 5)
```

## Dune Analytics Lenses

Dune Analytics requires an API key. You must configure `DUNE_API_KEY` in your environment.

- `Lux.Lenses.Dune.ExecuteQuery`: Executes a Dune query by its ID.
- `Lux.Lenses.Dune.GetQueryResults`: Fetches the results of an executed query using the execution ID.

### Example: Running a Custom Query

```elixir
# Execute query 12345
{:ok, %{execution_id: exec_id}} = Lux.Lenses.Dune.ExecuteQuery.focus(%{query_id: 12345})

# Fetch results
{:ok, %{status: "completed", rows: rows}} = Lux.Lenses.Dune.GetQueryResults.focus(%{execution_id: exec_id})
```

## Analytics Dashboard Prism

The `Lux.Prisms.Defi.AnalyticsDashboardPrism` aggregates data from multiple sources to provide a unified dashboard for a protocol.

```elixir
# Get aggregated metrics for Aave
{:ok, dashboard} = Lux.Prisms.Defi.AnalyticsDashboardPrism.run(%{protocol_slug: "aave"})

IO.inspect(dashboard.protocol["tvl"])
IO.inspect(dashboard.pools) # Top 5 pools for Aave
```

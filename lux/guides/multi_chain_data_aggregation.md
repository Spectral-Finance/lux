# Multi-Chain Data Aggregation

Lux can prepare a deterministic EVM aggregation plan without wallet secrets or
live RPC credentials. The `Lux.Integrations.MultiChain.Aggregator` module
normalizes supported chains, creates JSON-RPC requests for latest blocks and
event logs, and filters normalized logs for downstream query interfaces.

```elixir
{:ok, requests} =
  Lux.Integrations.MultiChain.Aggregator.latest_block_requests([
    "ethereum",
    "polygon",
    "base"
  ])
```

Each request includes the chain key, chain id, RPC URL, and JSON-RPC envelope.
A caller can execute the HTTP requests with its preferred transport and then
normalize responses:

```elixir
{:ok, block} =
  Lux.Integrations.MultiChain.Aggregator.normalize_block_response("ethereum", %{
    "result" => "0x14f46b4"
  })
```

Event indexing can be planned with `eth_getLogs` filters:

```elixir
{:ok, plan} =
  Lux.Integrations.MultiChain.Aggregator.subscription_plan(
    ["ethereum", "base"],
    [
      %{
        name: "usdc_transfers",
        address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        topic: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
        from_block: 20_000_000,
        to_block: "latest"
      }
    ],
    %{poll_interval_ms: 12_000}
  )
```

The generated plan includes:

- normalized chain metadata for Ethereum, Polygon, BSC, Arbitrum, Optimism,
  and Base
- JSON-RPC `eth_blockNumber` requests
- JSON-RPC `eth_getLogs` requests for each chain/filter pair
- a retention policy for raw logs, compaction, and checkpointing
- an event query helper for filtering normalized logs by chain, address,
  topic, and block range

For agent workflows, use
`Lux.Prisms.Web3.MultiChainDataAggregationPrism` to produce the same plan from
prism input.

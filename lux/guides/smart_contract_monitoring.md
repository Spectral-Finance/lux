# Smart Contract Event Monitoring

This guide covers the Etherscan-based smart contract event monitoring lenses available in Lux. These lenses enable real-time monitoring of on-chain events across multiple EVM-compatible blockchains.

## Overview

The Smart Contract Event Monitoring system provides five specialized lenses for tracking different types of on-chain activity:

| Lens | Purpose | Etherscan Module |
|------|---------|-----------------|
| `ContractEventLens` | Fetch contract event logs | `logs/getLogs` |
| `TokenTransferLens` | Track ERC-20 token transfers | `account/tokentx` |
| `InternalTransactionLens` | Monitor internal transactions | `account/txlistinternal` |
| `NewContractsLens` | Track new contract deployments | `contract/getcontractcreation` |
| `UniswapSwapLens` | Monitor Uniswap V3 swaps | `logs/getLogs` |

## Supported Chains

All lenses support the following EVM chains:

| Chain | Chain ID | Network |
|-------|----------|---------|
| Ethereum | 1 | Mainnet |
| Polygon | 137 | Mainnet |
| BSC | 56 | Mainnet |
| Arbitrum | 42161 | Mainnet |
| Optimism | 10 | Mainnet |

## Configuration

### 1. Set Up API Keys

Add your Etherscan API key to your environment configuration:

```bash
# In your .envrc or environment file
ETHERSCAN_API_KEY="your-etherscan-api-key"
```

### 2. Configure Lux

In `config/runtime.exs`:

```elixir
config :lux, Lux.Integrations.EtherscanMonitor,
  api_key: System.get_env("ETHERSCAN_API_KEY"),
  default_chain: System.get_env("ETHERSCAN_DEFAULT_CHAIN") || "ethereum"
```

## Usage

### Contract Event Monitoring

Fetch event logs from any smart contract:

```elixir
alias Lux.Lenses.Etherscan.Events.ContractEventLens

# Monitor Transfer events on UNI token
ContractEventLens.focus(%{
  contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
  topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
  from_block: 18_000_000,
  to_block: 18_001_000
})

# Monitor events on Polygon
ContractEventLens.focus(%{
  contract_address: "0x2791Bca1f2de4661ED88A30C99A7a1Aaf9c0b0d4",
  topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
  from_block: 45_000_000,
  to_block: 45_001_000,
  chainid: 137
})
```

**Response format:**

```elixir
{:ok, %{
  events: [
    %{
      address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
      topics: ["0xddf252ad...", "0x000000000...", "0x000000000..."],
      data: "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
      block_number: "18000001",
      timestamp: "1690000000",
      gas_price: "20000000000",
      gas_used: "45000",
      log_index: "50",
      transaction_hash: "0xabc123...",
      transaction_index: "10"
    }
  ],
  count: 1
}}
```

### Token Transfer Tracking

Track ERC-20 token transfers for a specific contract or wallet:

```elixir
alias Lux.Lenses.Etherscan.Events.TokenTransferLens

# Get recent UNI token transfers
TokenTransferLens.focus(%{
  contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
  page: 1,
  offset: 50
})

# Filter by specific wallet address
TokenTransferLens.focus(%{
  contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
  wallet_address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
  page: 1,
  offset: 20
})
```

**Response format:**

```elixir
{:ok, %{
  transfers: [
    %{
      hash: "0xabc123...",
      from: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
      to: "0xa79e63e78eec28741e711f89a672a4c40876ebf3",
      value: "1000000000000000000",
      contract_address: "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984",
      token_name: "Uniswap",
      token_symbol: "UNI",
      token_decimals: "18",
      block_number: "18000001",
      timestamp: "1690000000",
      gas: "50000",
      gas_price: "20000000000",
      gas_used: "45000"
    }
  ],
  count: 1
}}
```

### Internal Transaction Monitoring

Monitor internal (contract-to-contract) transactions:

```elixir
alias Lux.Lenses.Etherscan.Events.InternalTransactionLens

# Get internal transactions for an address
InternalTransactionLens.focus(%{
  address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
  start_block: 18_000_000,
  end_block: 18_001_000,
  page: 1,
  offset: 50
})
```

**Response format:**

```elixir
{:ok, %{
  internal_transactions: [
    %{
      hash: "0xabc123...",
      from: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
      to: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
      value: "1000000000000000000",
      type: "call",
      gas: "50000",
      gas_used: "45000",
      block_number: "18000001",
      timestamp: "1690000000",
      is_error: "0"
    }
  ],
  count: 1
}}
```

### New Contract Deployment Tracking

Monitor newly deployed smart contracts:

```elixir
alias Lux.Lenses.Etherscan.Events.NewContractsLens

# Get new contracts deployed in a block range
NewContractsLens.focus(%{
  block_start: 18_000_000,
  block_end: 18_001_000,
  page: 1,
  offset: 100
})

# Monitor on BSC
NewContractsLens.focus(%{
  block_start: 30_000_000,
  block_end: 30_001_000,
  chainid: 56,
  page: 1
})
```

**Response format:**

```elixir
{:ok, %{
  contracts: [
    %{
      contract_address: "0xB83c27805aAcA5C7082eB45C868d955Cf04C337F",
      contract_creator: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
      tx_hash: "0xabc123...",
      block_number: "18000001",
      method_id: "0x608060",
      create2_key: ""
    }
  ],
  count: 1
}}
```

### Uniswap V3 Swap Monitoring

Monitor Uniswap V3 swap events:

```elixir
alias Lux.Lenses.Etherscan.Events.UniswapSwapLens

# Monitor WETH/USDC 0.05% pool swaps
UniswapSwapLens.focus(%{
  pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
  from_block: 18_000_000,
  to_block: 18_001_000,
  page: 1,
  offset: 100
})

# Filter by minimum amount
UniswapSwapLens.focus(%{
  pool_address: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
  min_amount: "1000000",
  from_block: 18_000_000,
  to_block: 18_001_000
})
```

**Response format:**

```elixir
{:ok, %{
  swaps: [
    %{
      pool: "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640",
      transaction_hash: "0xswap123...",
      block_number: "18000001",
      timestamp: "1690000000",
      sender: "0xc5102fe9359fd9a28f877a67e36b0f050d81a3cc",
      recipient: "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45",
      amount0: "1000000",
      amount1: "500000",
      sqrt_price_x96: "...",
      liquidity: "...",
      tick: "...",
      gas_price: "20000000000",
      gas_used: "80000"
    }
  ],
  count: 1
}}
```

## Common Event Signatures

### ERC-20 / ERC-721 Events

| Event | Signature | topic0 |
|-------|-----------|--------|
| Transfer | `Transfer(address,address,uint256)` | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |
| Approval | `Approval(address,address,uint256)` | `0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925` |

### Uniswap V3 Events

| Event | Signature | topic0 |
|-------|-----------|--------|
| Swap | `Swap(address,address,int256,int256,uint160,uint128,int24)` | `0xc42079f94a6350d7e6235f29174924f91065fbc2da3237a9a9b3f4a31aace1a1` |
| Mint | `Mint(address,address,int24,int24,uint128,uint256,uint256)` | `0x7a5320e7881b1b4e195ebe0df33a3a39a333b6c5f0b5a467f54f5f5b5b5b5b5b` |
| Collect | `Collect(address,address,int24,int24,uint128,uint256,uint256)` | `0x...` |

## Multi-Chain Examples

### Cross-Chain Token Transfer Monitoring

```elixir
defmodule MyApp.Monitor do
  alias Lux.Lenses.Etherscan.Events.TokenTransferLens

  @tokens %{
    ethereum: ["0x1f9840a85d5af5bf1d1762f925bdaddc4201f984"],  # UNI
    polygon: ["0x2791Bca1f2de4661ED88A30C99A7a1Aaf9c0b0d4"],  # Chainlink
    arbitrum: ["0xfc5a1a6eb076a2c7ad06ed22c90d7e710e35ad0a"]   # GMX
  }

  def monitor_all_chains(wallet_address) do
    for {chain, tokens} <- @tokens, token <- tokens do
      chainid = chain_id(chain)

      TokenTransferLens.focus(%{
        contract_address: token,
        wallet_address: wallet_address,
        chainid: chainid,
        page: 1,
        offset: 10
      })
    end
  end

  defp chain_id(:ethereum), do: 1
  defp chain_id(:polygon), do: 137
  defp chain_id(:bsc), do: 56
  defp chain_id(:arbitrum), do: 42161
  defp chain_id(:optimism), do: 10
end
```

### New Contract Scanner

```elixir
defmodule MyApp.ContractScanner do
  alias Lux.Lenses.Etherscan.Events.NewContractsLens

  def scan_latest_blocks(chainid \\ 1, blocks \\ 1000) do
    latest_block = get_latest_block(chainid)

    NewContractsLens.focus(%{
      block_start: latest_block - blocks,
      block_end: latest_block,
      chainid: chainid,
      page: 1,
      offset: 1000
    })
  end

  defp get_latest_block(_chainid) do
    # In production, fetch from an RPC node or Etherscan
    18_000_000
  end
end
```

## Error Handling

All lenses return consistent error formats:

```elixir
# API error
{:error, %{message: "Error", result: "Invalid address format"}}

# Rate limiting
{:error, "API rate limit exceeded"}

# Pro API key required
{:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}}

# Network error
{:error, "connection refused"}
```

## Rate Limiting

Etherscan API has rate limits:

- **Free tier**: 5 calls/second, 100,000 calls/day
- **Pro tier**: Higher limits available

Consider implementing rate limiting in your application:

```elixir
# Using Hammer for rate limiting
defmodule MyApp.RateLimiter do
  use Hammer

  def rate_limit(key, limit \\ 5, window \\ 1000) do
    Hammer.backend().check_rate(key, limit, window)
  end
end
```

## Testing

Run the test suite:

```bash
cd lux
mix test test/unit/lux/lenses/etherscan_event_monitor_test.exs
```

## Integration with Lux Agents

These lenses can be used directly by Lux agents:

```elixir
defmodule MyApp.Agents.MonitorAgent do
  use Lux.Agent

  alias Lux.Lenses.Etherscan.Events.TokenTransferLens

  def handle_signal(%Lux.Signal{type: :check_transfers, data: data}, state) do
    case TokenTransferLens.focus(%{
      contract_address: data.contract_address,
      wallet_address: data.wallet_address,
      page: 1,
      offset: 10
    }) do
      {:ok, %{transfers: transfers}} ->
        # Process transfers
        {:reply, %{transfers: transfers}, state}

      {:error, reason} ->
        {:reply, %{error: reason}, state}
    end
  end
end
```

## Troubleshooting

### Common Issues

1. **Invalid API Key**: Ensure your `ETHERSCAN_API_KEY` is set correctly in your environment.

2. **Rate Limiting**: If you receive rate limit errors, implement request throttling.

3. **Invalid Address Format**: Ensure all addresses are valid 0x-prefixed hex strings (42 characters).

4. **Block Range Too Large**: Etherscan may limit the block range. Use smaller ranges (10,000 blocks) for better results.

5. **Pro API Required**: Some endpoints require a Pro API key. Check the Etherscan documentation for endpoint requirements.

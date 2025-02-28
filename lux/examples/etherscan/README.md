# Etherscan Lens Examples

This directory contains example scripts demonstrating how to use the Etherscan lenses in the Lux library. These examples showcase various features of the Etherscan API and how to interact with them using the Lux lenses.

## Prerequisites

Before running these examples, make sure you have:

1. An Etherscan API key (get one for free at [etherscan.io](https://etherscan.io/apis))
2. For Pro API features, a Pro API key subscription from Etherscan
3. Elixir and the Lux library installed

## Configuration

Set the following environment variables:

```bash
# Required for all examples
export ETHERSCAN_API_KEY=your_api_key_here

# For Pro API features
export ETHERSCAN_API_KEY_PRO=true  # Only if you have a Pro API key

# For multichain examples
export BSCSCAN_API_KEY=your_bscscan_api_key_here
export POLYGONSCAN_API_KEY=your_polygonscan_api_key_here
export ARBISCAN_API_KEY=your_arbiscan_api_key_here
export OPTIMISM_API_KEY=your_optimism_api_key_here
```

Alternatively, you can configure these in your application's config files.

## Available Examples

### 1. Basic Examples (`basic_examples.exs`)

Demonstrates basic usage of all Etherscan lenses, including:
- Account balance queries
- Block information
- Gas prices
- Token data
- Transaction status
- Contract information
- Event logs

**Run with:**
```bash
mix run examples/etherscan/basic_examples.exs
```

### 2. Multichain Examples (`multichain_examples.exs`)

Shows how to use Etherscan lenses with different blockchain networks:
- Ethereum Mainnet
- Binance Smart Chain
- Polygon
- Arbitrum
- Optimism

Compares data across chains, such as gas prices and token information.

**Run with:**
```bash
mix run examples/etherscan/multichain_examples.exs
```

### 3. Token Analysis (`token_analysis.exs`)

Provides a more in-depth analysis of token data, including:
- Token supply and holder information
- Contract details
- Token transfers
- ERC20 and ERC721 token holdings

**Run with:**
```bash
mix run examples/etherscan/token_analysis.exs
```

### 4. Gas Tracker (`gas_tracker.exs`)

Focuses on gas price analysis and estimation:
- Current gas prices
- Transaction cost estimation
- Confirmation time prediction
- Historical gas data analysis

**Run with:**
```bash
mix run examples/etherscan/gas_tracker.exs
```

## Pro API Features

Some endpoints in the Etherscan API require a Pro API key subscription. These examples will indicate when a Pro API key is required and will handle the case when one is not available.

Pro API features include:
- Historical token supply and balances
- Token holder lists and counts
- Token information
- Address token holdings
- Historical gas data
- Daily network statistics

## Etherscan Lens Modules

These examples use the following lens modules:

- `Lux.Lenses.Etherscan.AccountLens` - Account balances and transactions
- `Lux.Lenses.Etherscan.BlockLens` - Block information and rewards
- `Lux.Lenses.Etherscan.ContractLens` - Smart contract data and verification
- `Lux.Lenses.Etherscan.GasLens` - Gas prices and estimates
- `Lux.Lenses.Etherscan.LogsLens` - Event logs and filtering
- `Lux.Lenses.Etherscan.StatsLens` - Network statistics
- `Lux.Lenses.Etherscan.TokenLens` - Token data and holdings
- `Lux.Lenses.Etherscan.TransactionLens` - Transaction status and receipts

## Rate Limiting

Be aware that the Etherscan API has rate limits:
- Free API: 5 calls/second
- Pro API: Varies by subscription level

These examples do not implement rate limiting, so you may encounter rate limit errors if you run them repeatedly in quick succession.

## Additional Resources

- [Etherscan API Documentation](https://docs.etherscan.io/)
- [Lux Documentation](https://hexdocs.pm/lux)
- [Etherscan API Key Registration](https://etherscan.io/apis) 
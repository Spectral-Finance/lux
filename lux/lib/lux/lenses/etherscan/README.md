# Etherscan Lenses for Lux

This directory contains a collection of lens modules for interacting with the Etherscan API. These lenses provide a convenient and structured way to access various Etherscan endpoints for retrieving blockchain data from Ethereum and compatible networks.

## Overview

The Etherscan lenses are organized into several modules, each focusing on a specific aspect of the Etherscan API:

- **AccountLens**: Account-related data (balances, transactions, token transfers)
- **BlockLens**: Block-related data (rewards, transaction counts, timing)
- **ContractLens**: Smart contract data (source code, ABI, verification)
- **GasLens**: Gas-related data (gas prices, estimates, historical gas data)
- **LogsLens**: Event logs and filtering
- **StatsLens**: Network statistics (supply, price, node count)
- **TokenLens**: Token-related data (supply, balances, holders)
- **TransactionLens**: Transaction status and receipts
- **BaseLens**: Common functionality shared across all lenses

## Features

- **Comprehensive API Coverage**: Access to most Etherscan API endpoints
- **Multi-chain Support**: Works with Ethereum, BSC, Polygon, Arbitrum, Optimism, and other EVM-compatible chains
- **Pro API Support**: Handles Pro-only endpoints with appropriate error handling
- **Parameter Validation**: Validates input parameters before making API calls
- **Error Handling**: Consistent error handling across all lenses

## Usage

### Configuration

Configure your Etherscan API key in your application's configuration:

```elixir
# In config/config.exs
config :lux, :api_keys, [
  etherscan: "YOUR_ETHERSCAN_API_KEY",
  etherscan_pro: true  # Set to true if you have a Pro API key
]
```

Alternatively, you can set the API key as an environment variable:

```bash
export ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
export ETHERSCAN_API_KEY_PRO=true  # Only if you have a Pro API key
```

### Basic Examples

```elixir
alias Lux.Lenses.Etherscan.AccountLens
alias Lux.Lenses.Etherscan.TokenLens
alias Lux.Lenses.Etherscan.GasLens

# Get ETH balance for an address
{:ok, %{result: balance}} = AccountLens.get_eth_balance(%{
  address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
})

# Get token supply for USDT
{:ok, %{result: supply}} = TokenLens.get_token_supply(%{
  contractaddress: "0xdac17f958d2ee523a2206206994597c13d831ec7"
})

# Get current gas prices
{:ok, %{result: gas_data}} = GasLens.get_gas_oracle()
```

### Multi-chain Examples

```elixir
# Get ETH balance on Ethereum
{:ok, %{result: eth_balance}} = AccountLens.get_eth_balance(%{
  address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
  network: :ethereum
})

# Get BNB balance on Binance Smart Chain
{:ok, %{result: bnb_balance}} = AccountLens.get_eth_balance(%{
  address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
  network: :bsc
})

# Get MATIC balance on Polygon
{:ok, %{result: matic_balance}} = AccountLens.get_eth_balance(%{
  address: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
  network: :polygon
})
```

## Module Details

### AccountLens

Provides access to account-related endpoints:

- `get_eth_balance/1`: Get ETH balance for an address
- `get_eth_balance_multi/1`: Get ETH balance for multiple addresses
- `get_eth_balance_history/1`: Get historical ETH balance (Pro API)
- `get_token_balance/1`: Get token balance for an address
- `get_normal_transactions/1`: Get normal transactions for an address
- `get_internal_transactions/1`: Get internal transactions for an address
- `get_erc20_token_transfers/1`: Get ERC20 token transfers for an address
- `get_erc721_token_transfers/1`: Get ERC721 token transfers for an address
- `get_erc1155_token_transfers/1`: Get ERC1155 token transfers for an address
- `get_mined_blocks/1`: Get blocks mined by an address
- `get_beacon_withdrawals/1`: Get beacon chain withdrawals for an address

### BlockLens

Provides access to block-related endpoints:

- `get_block_reward/1`: Get block and uncle rewards
- `get_block_txns_count/1`: Get transaction count for a block
- `get_block_countdown/1`: Get estimated time until a block is mined
- `get_block_no_by_time/1`: Get block number by timestamp
- `get_daily_avg_block_size/1`: Get daily average block size (Pro API)
- `get_daily_block_count/1`: Get daily block count (Pro API)
- `get_daily_block_rewards/1`: Get daily block rewards (Pro API)
- `get_daily_avg_block_time/1`: Get daily average block time (Pro API)
- `get_daily_uncle_block_count/1`: Get daily uncle block count (Pro API)

### ContractLens

Provides access to contract-related endpoints:

- `get_contract_source_code/1`: Get source code for a verified contract
- `get_contract_abi/1`: Get ABI for a verified contract
- `get_contract_creation_info/1`: Get contract creation information
- `is_contract_verified/1`: Check if a contract is verified
- `get_contract_execution_status/1`: Get contract execution status
- `check_verification_status/1`: Check contract verification status
- `verify_contract_source_code/1`: Verify contract source code
- `get_verified_contracts/1`: Get list of verified contracts

### GasLens

Provides access to gas-related endpoints:

- `get_gas_estimate/1`: Get estimated confirmation time for a gas price
- `get_gas_oracle/0`: Get current gas prices
- `get_daily_avg_gas_limit/1`: Get daily average gas limit (Pro API)
- `get_daily_gas_used/1`: Get daily gas used (Pro API)
- `get_daily_avg_gas_price/1`: Get daily average gas price (Pro API)

### LogsLens

Provides access to event log endpoints:

- `get_logs_by_address/1`: Get event logs for an address
- `get_logs_by_topics/1`: Get event logs filtered by topics
- `get_logs/1`: Get event logs by address and topics

### StatsLens

Provides access to network statistics endpoints:

- `get_eth_supply/0`: Get total Ether supply
- `get_eth_supply2/0`: Get detailed Ether supply
- `get_eth_price/0`: Get current Ether price
- `get_chain_size/1`: Get Ethereum blockchain size
- `get_node_count/0`: Get total Ethereum nodes count
- `get_daily_txn_fee/1`: Get daily transaction fees (Pro API)
- `get_daily_new_address/1`: Get daily new address count (Pro API)
- `get_daily_network_utilization/1`: Get daily network utilization (Pro API)
- `get_daily_avg_hashrate/1`: Get daily average hash rate (Pro API)
- `get_daily_tx_count/1`: Get daily transaction count (Pro API)
- `get_daily_avg_network_difficulty/1`: Get daily average network difficulty (Pro API)
- `get_eth_historical_price/1`: Get historical Ether price (Pro API)

### TokenLens

Provides access to token-related endpoints:

- `get_token_supply/1`: Get token total supply
- `get_token_balance/1`: Get token balance for an address
- `get_historical_token_supply/1`: Get historical token supply (Pro API)
- `get_historical_token_balance/1`: Get historical token balance (Pro API)
- `get_token_holder_list/1`: Get token holder list (Pro API)
- `get_token_holder_count/1`: Get token holder count (Pro API)
- `get_token_info/1`: Get token information (Pro API)
- `get_address_erc20_token_holdings/1`: Get ERC20 token holdings for an address (Pro API)
- `get_address_erc721_token_holdings/1`: Get ERC721 token holdings for an address (Pro API)
- `get_address_erc721_token_inventory/1`: Get ERC721 token inventory for an address (Pro API)

### TransactionLens

Provides access to transaction-related endpoints:

- `get_contract_execution_status/1`: Get contract execution status for a transaction
- `get_tx_receipt_status/1`: Get transaction receipt status

## Rate Limiting

The Etherscan API has rate limits:
- Free API: 5 calls/second
- Pro API: Varies by subscription level

When making multiple API calls, it's recommended to add a delay between calls to avoid hitting the rate limit:

```elixir
Process.sleep(300)  # 300ms delay between API calls
```

## Error Handling

All lens functions return either:
- `{:ok, %{result: data}}` on success
- `{:error, reason}` on failure

For Pro API endpoints, if a Pro API key is not available, the error will be:
- `{:error, "This endpoint requires a Pro API key subscription"}`

## Additional Resources

- [Etherscan API Documentation](https://docs.etherscan.io/)
- [Etherscan API Key Registration](https://etherscan.io/apis) 
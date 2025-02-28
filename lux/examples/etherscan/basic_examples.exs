#!/usr/bin/env elixir

# Basic Examples for Etherscan Lenses
#
# This script demonstrates basic usage of various Etherscan lenses.
# To run this script:
#   1. Make sure you have set the ETHERSCAN_API_KEY environment variable
#   2. Run: mix run examples/etherscan/basic_examples.exs

# Import required modules
alias Lux.Lenses.Etherscan.AccountLens
alias Lux.Lenses.Etherscan.BlockLens
alias Lux.Lenses.Etherscan.ContractLens
alias Lux.Lenses.Etherscan.GasLens
alias Lux.Lenses.Etherscan.LogsLens
alias Lux.Lenses.Etherscan.StatsLens
alias Lux.Lenses.Etherscan.TokenLens
alias Lux.Lenses.Etherscan.TransactionLens

# Helper function to print results
defmodule Helper do
  # Add a delay between API calls to avoid rate limiting
  @delay_ms 300

  def print_result(title, result) do
    IO.puts("\n=== #{title} ===")

    case result do
      {:ok, %{result: data}} ->
        IO.puts("Success! Result:")
        IO.inspect(data, pretty: true, limit: 5)
      {:error, error} ->
        IO.puts("Error:")
        IO.inspect(error, pretty: true)
    end
  end

  def with_rate_limit(fun) do
    Process.sleep(@delay_ms)
    fun.()
  end
end

IO.puts("Starting Etherscan API Examples...")

# Account Lens Examples
IO.puts("\n## ACCOUNT LENS EXAMPLES ##")

# Get ETH balance for an address
vitalik_address = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045"
result = Helper.with_rate_limit(fn -> AccountLens.get_eth_balance(%{address: vitalik_address}) end)
Helper.print_result("ETH Balance for Vitalik's Address", result)

# Get ETH balance for multiple addresses
addresses = [
  "0xd8da6bf26964af9d7eed9e03e53415d37aa96045", # Vitalik's address
  "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"  # Bitfinex's address
]
result = Helper.with_rate_limit(fn -> AccountLens.get_eth_balance_multi(%{addresses: addresses}) end)
Helper.print_result("ETH Balance for Multiple Addresses", result)

# Block Lens Examples
IO.puts("\n## BLOCK LENS EXAMPLES ##")

# Get block reward
result = Helper.with_rate_limit(fn -> BlockLens.get_block_reward(%{blockno: 17000000}) end)
Helper.print_result("Block Reward for Block 17000000", result)

# Get block transactions count
result = Helper.with_rate_limit(fn -> BlockLens.get_block_txns_count(%{blockno: 17000000}) end)
Helper.print_result("Block Transactions Count for Block 17000000", result)

# Get block number by timestamp
result = Helper.with_rate_limit(fn -> BlockLens.get_block_no_by_time(%{timestamp: 1609459200, closest: "before"}) end)
Helper.print_result("Block Number on Jan 1, 2021", result)

# Gas Lens Examples
IO.puts("\n## GAS LENS EXAMPLES ##")

# Get gas oracle data
result = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle() end)
Helper.print_result("Current Gas Oracle Data", result)

# Get gas estimate
result = Helper.with_rate_limit(fn -> GasLens.get_gas_estimate(%{gasprice: "2000000000"}) end)
Helper.print_result("Gas Estimate for 2 Gwei", result)

# Stats Lens Examples
IO.puts("\n## STATS LENS EXAMPLES ##")

# Get total Ether supply
result = Helper.with_rate_limit(fn -> StatsLens.get_eth_supply() end)
Helper.print_result("Total Ether Supply", result)

# Get Ether price
result = Helper.with_rate_limit(fn -> StatsLens.get_eth_price() end)
Helper.print_result("Current Ether Price", result)

# Get node count
result = Helper.with_rate_limit(fn -> StatsLens.get_node_count() end)
Helper.print_result("Total Ethereum Nodes", result)

# Token Lens Examples
IO.puts("\n## TOKEN LENS EXAMPLES ##")

# Get token supply for USDT
usdt_address = "0xdac17f958d2ee523a2206206994597c13d831ec7"
result = Helper.with_rate_limit(fn -> TokenLens.get_token_supply(%{contractaddress: usdt_address}) end)
Helper.print_result("USDT Token Supply", result)

# Get token balance for an address
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_balance(%{
    contractaddress: usdt_address,
    address: "0x5041ed759Dd4aFc3a72b8192C143F72f4724081A"
  })
end)
Helper.print_result("USDT Balance for Address", result)

# Transaction Lens Examples
IO.puts("\n## TRANSACTION LENS EXAMPLES ##")

# Get transaction receipt status
tx_hash = "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"
result = Helper.with_rate_limit(fn -> TransactionLens.get_tx_receipt_status(%{txhash: tx_hash}) end)
Helper.print_result("Transaction Receipt Status", result)

# Contract Lens Examples
IO.puts("\n## CONTRACT LENS EXAMPLES ##")

# Get contract ABI
usdc_address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
result = Helper.with_rate_limit(fn -> ContractLens.get_contract_abi(%{address: usdc_address}) end)
Helper.print_result("USDC Contract ABI", result)

# Logs Lens Examples
IO.puts("\n## LOGS LENS EXAMPLES ##")

# Get logs by address
nft_address = "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
result = Helper.with_rate_limit(fn ->
  LogsLens.get_logs_by_address(%{
    address: nft_address,
    fromBlock: 12878196,
    toBlock: 12878196
  })
end)
Helper.print_result("Logs for NFT Contract", result)

IO.puts("\nAll examples completed!")

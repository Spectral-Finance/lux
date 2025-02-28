#!/usr/bin/env elixir

# Multichain Examples for Etherscan Lenses
#
# This script demonstrates how to use Etherscan lenses with different networks.
# To run this script:
#   1. Make sure you have set the appropriate API keys:
#      - ETHERSCAN_API_KEY for Ethereum
#      - BSCSCAN_API_KEY for Binance Smart Chain
#      - POLYGONSCAN_API_KEY for Polygon
#      - ARBISCAN_API_KEY for Arbitrum
#      - OPTIMISM_API_KEY for Optimism
#   2. Run: mix run examples/etherscan/multichain_examples.exs

# Import required modules
alias Lux.Lenses.Etherscan.AccountLens
alias Lux.Lenses.Etherscan.BlockLens
alias Lux.Lenses.Etherscan.StatsLens
alias Lux.Lenses.Etherscan.TokenLens
alias Lux.Lenses.Etherscan.GasLens

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

IO.puts("Starting Multichain Etherscan API Examples...")

# Define a test address to use across chains
test_address = "0xd8da6bf26964af9d7eed9e03e53415d37aa96045" # Vitalik's address

# Define token addresses on different chains
tokens = %{
  ethereum: "0xdac17f958d2ee523a2206206994597c13d831ec7", # USDT on Ethereum
  bsc: "0x55d398326f99059ff775485246999027b3197955",     # USDT on BSC
  polygon: "0xc2132d05d31c914a87c6611c10748aeb04b58e8f", # USDT on Polygon
  arbitrum: "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", # USDT on Arbitrum
  optimism: "0x94b008aa00579c1307b0ef2c499ad98a8ce58e58"  # USDT on Optimism
}

# Ethereum Mainnet Examples
IO.puts("\n## ETHEREUM MAINNET EXAMPLES ##")

# Get ETH balance
result = Helper.with_rate_limit(fn ->
  AccountLens.get_eth_balance(%{
    address: test_address,
    network: :ethereum
  })
end)
Helper.print_result("ETH Balance on Ethereum", result)

# Get token supply
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_supply(%{
    contractaddress: tokens.ethereum,
    network: :ethereum
  })
end)
Helper.print_result("USDT Supply on Ethereum", result)

# Get gas oracle data
result = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :ethereum}) end)
Helper.print_result("Gas Oracle on Ethereum", result)

# Get block reward
result = Helper.with_rate_limit(fn ->
  BlockLens.get_block_reward(%{
    blockno: 17000000,
    network: :ethereum
  })
end)
Helper.print_result("Block Reward on Ethereum", result)

# Binance Smart Chain Examples
IO.puts("\n## BINANCE SMART CHAIN EXAMPLES ##")

# Get BNB balance
result = Helper.with_rate_limit(fn ->
  AccountLens.get_eth_balance(%{
    address: test_address,
    network: :bsc
  })
end)
Helper.print_result("BNB Balance on BSC", result)

# Get token supply
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_supply(%{
    contractaddress: tokens.bsc,
    network: :bsc
  })
end)
Helper.print_result("USDT Supply on BSC", result)

# Get gas oracle data
result = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :bsc}) end)
Helper.print_result("Gas Oracle on BSC", result)

# Polygon Examples
IO.puts("\n## POLYGON EXAMPLES ##")

# Get MATIC balance
result = Helper.with_rate_limit(fn ->
  AccountLens.get_eth_balance(%{
    address: test_address,
    network: :polygon
  })
end)
Helper.print_result("MATIC Balance on Polygon", result)

# Get token supply
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_supply(%{
    contractaddress: tokens.polygon,
    network: :polygon
  })
end)
Helper.print_result("USDT Supply on Polygon", result)

# Arbitrum Examples
IO.puts("\n## ARBITRUM EXAMPLES ##")

# Get ETH balance on Arbitrum
result = Helper.with_rate_limit(fn ->
  AccountLens.get_eth_balance(%{
    address: test_address,
    network: :arbitrum
  })
end)
Helper.print_result("ETH Balance on Arbitrum", result)

# Get token supply
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_supply(%{
    contractaddress: tokens.arbitrum,
    network: :arbitrum
  })
end)
Helper.print_result("USDT Supply on Arbitrum", result)

# Optimism Examples
IO.puts("\n## OPTIMISM EXAMPLES ##")

# Get ETH balance on Optimism
result = Helper.with_rate_limit(fn ->
  AccountLens.get_eth_balance(%{
    address: test_address,
    network: :optimism
  })
end)
Helper.print_result("ETH Balance on Optimism", result)

# Get token supply
result = Helper.with_rate_limit(fn ->
  TokenLens.get_token_supply(%{
    contractaddress: tokens.optimism,
    network: :optimism
  })
end)
Helper.print_result("USDT Supply on Optimism", result)

# Compare gas prices across chains
IO.puts("\n## CROSS-CHAIN GAS PRICE COMPARISON ##")

# Get gas prices on different chains
ethereum_gas = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :ethereum}) end)
bsc_gas = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :bsc}) end)
polygon_gas = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :polygon}) end)
arbitrum_gas = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :arbitrum}) end)
optimism_gas = Helper.with_rate_limit(fn -> GasLens.get_gas_oracle(%{network: :optimism}) end)

# Extract safe gas prices
gas_prices = %{
  ethereum: case ethereum_gas do
    {:ok, %{result: data}} -> data["SafeGasPrice"]
    _ -> "N/A"
  end,
  bsc: case bsc_gas do
    {:ok, %{result: data}} -> data["SafeGasPrice"]
    _ -> "N/A"
  end,
  polygon: case polygon_gas do
    {:ok, %{result: data}} -> data["SafeGasPrice"]
    _ -> "N/A"
  end,
  arbitrum: case arbitrum_gas do
    {:ok, %{result: data}} -> data["SafeGasPrice"]
    _ -> "N/A"
  end,
  optimism: case optimism_gas do
    {:ok, %{result: data}} -> data["SafeGasPrice"]
    _ -> "N/A"
  end
}

IO.puts("\n=== Gas Price Comparison (Safe Gas Price in Gwei) ===")
IO.puts("Ethereum: #{gas_prices.ethereum}")
IO.puts("BSC: #{gas_prices.bsc}")
IO.puts("Polygon: #{gas_prices.polygon}")
IO.puts("Arbitrum: #{gas_prices.arbitrum}")
IO.puts("Optimism: #{gas_prices.optimism}")

IO.puts("\nAll multichain examples completed!")

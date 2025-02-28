#!/usr/bin/env elixir

# Token Analysis Example for Etherscan Lenses
#
# This script demonstrates how to use Etherscan lenses to analyze token data.
# To run this script:
#   1. Make sure you have set the ETHERSCAN_API_KEY environment variable
#   2. For Pro API features, set ETHERSCAN_API_KEY_PRO=true
#   3. Run: mix run examples/etherscan/token_analysis.exs

# Import required modules
alias Lux.Lenses.Etherscan.TokenLens
alias Lux.Lenses.Etherscan.AccountLens
alias Lux.Lenses.Etherscan.ContractLens

# Helper function to print results
defmodule Helper do
  @delay_ms 500

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

  def print_section(title) do
    IO.puts("\n\n" <> String.duplicate("=", 50))
    IO.puts("#{title}")
    IO.puts(String.duplicate("=", 50))
  end
end

Helper.print_section("TOKEN ANALYSIS EXAMPLE")
IO.puts("This example demonstrates how to analyze token data using Etherscan lenses.")

# Define token addresses to analyze
tokens = [
  %{
    name: "USDT (Tether)",
    address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
    type: "ERC20"
  },
  %{
    name: "USDC",
    address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
    type: "ERC20"
  },
  %{
    name: "WETH (Wrapped Ether)",
    address: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
    type: "ERC20"
  },
  %{
    name: "Bored Ape Yacht Club",
    address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
    type: "ERC721"
  }
]

# Analyze each token
Enum.each(tokens, fn token ->
  Helper.print_section("ANALYZING #{token.name} (#{token.address})")

  # Get token supply
  supply_result = TokenLens.get_token_supply(%{
    contractaddress: token.address
  })
  Helper.print_result("Token Supply", supply_result)

  # Get contract source code
  source_result = ContractLens.get_contract_source_code(%{
    address: token.address
  })

  # Extract contract name and compiler version
  contract_info = case source_result do
    {:ok, %{result: [first | _]}} ->
      %{
        name: first["ContractName"],
        compiler: first["CompilerVersion"],
        optimization: first["OptimizationUsed"]
      }
    _ ->
      %{name: "Unknown", compiler: "Unknown", optimization: "Unknown"}
  end

  IO.puts("\n=== Contract Information ===")
  IO.puts("Contract Name: #{contract_info.name}")
  IO.puts("Compiler Version: #{contract_info.compiler}")
  IO.puts("Optimization: #{contract_info.optimization}")

  # Get contract creation info
  creation_result = ContractLens.get_contract_creation_info(%{
    contractaddresses: token.address
  })
  Helper.print_result("Contract Creation Info", creation_result)

  # Get token info (Pro API feature)
  token_info_result = TokenLens.get_token_info(%{
    contractaddress: token.address
  })
  Helper.print_result("Token Info (Pro API)", token_info_result)

  # Get token holder count (Pro API feature)
  holder_count_result = TokenLens.get_token_holder_count(%{
    contractaddress: token.address
  })
  Helper.print_result("Token Holder Count (Pro API)", holder_count_result)

  # Get token holder list (Pro API feature)
  holder_list_result = TokenLens.get_token_holder_list(%{
    contractaddress: token.address,
    page: 1,
    offset: 5
  })
  Helper.print_result("Top 5 Token Holders (Pro API)", holder_list_result)

  # If this is an ERC721 token, try to get a specific holder's inventory
  if token.type == "ERC721" do
    # Try to extract a holder address from the holder list
    holder_address = case holder_list_result do
      {:ok, %{result: [first | _]}} -> first["TokenHolderAddress"]
      _ -> "0x123432244443b54409430979df8333f9308a6040" # Fallback to a known holder
    end

    inventory_result = TokenLens.get_address_erc721_token_inventory(%{
      address: holder_address,
      contractaddress: token.address,
      page: 1,
      offset: 5
    })
    Helper.print_result("Sample NFT Inventory for #{holder_address} (Pro API)", inventory_result)
  end

  IO.puts("\n" <> String.duplicate("-", 50))
end)

# Analyze an address's token holdings
Helper.print_section("ANALYZING ADDRESS TOKEN HOLDINGS")

# Define address to analyze
address = "0x28c6c06298d514db089934071355e5743bf21d60" # Binance 14 wallet

IO.puts("Analyzing token holdings for address: #{address}")

# Get ERC20 token holdings (Pro API feature)
erc20_holdings_result = TokenLens.get_address_erc20_token_holdings(%{
  address: address,
  page: 1,
  offset: 10
})
Helper.print_result("ERC20 Token Holdings (Pro API)", erc20_holdings_result)

# Get ERC721 token holdings (Pro API feature)
erc721_holdings_result = TokenLens.get_address_erc721_token_holdings(%{
  address: address,
  page: 1,
  offset: 10
})
Helper.print_result("ERC721 Token Holdings (Pro API)", erc721_holdings_result)

# Get token transfer history
token_transfers_result = AccountLens.get_erc20_token_transfers(%{
  address: address,
  startblock: 0,
  endblock: 99999999,
  page: 1,
  offset: 10
})
Helper.print_result("Recent ERC20 Token Transfers", token_transfers_result)

Helper.print_section("TOKEN ANALYSIS COMPLETE")
IO.puts("Note: Some features require a Pro API key subscription.")
IO.puts("If you see 'This endpoint requires a Pro API key subscription' errors,")
IO.puts("you need to set ETHERSCAN_API_KEY_PRO=true and use a valid Pro API key.")

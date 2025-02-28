#!/usr/bin/env elixir

# Gas Tracker Example for Etherscan Lenses
#
# This script demonstrates how to use the Gas Lens to track and analyze gas prices.
# To run this script:
#   1. Make sure you have set the ETHERSCAN_API_KEY environment variable
#   2. For Pro API features, set ETHERSCAN_API_KEY_PRO=true
#   3. Run: mix run examples/etherscan/gas_tracker.exs

# Import required modules
alias Lux.Lenses.Etherscan.GasLens
alias Lux.Lenses.Etherscan.StatsLens

# Helper function to print results
defmodule Helper do
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

  def format_gwei(wei_value) when is_binary(wei_value) do
    case Integer.parse(wei_value) do
      {value, _} -> format_gwei(value)
      :error -> "N/A"
    end
  end

  def format_gwei(wei_value) when is_integer(wei_value) do
    gwei = wei_value / 1_000_000_000
    :io_lib.format("~.2f", [gwei]) |> to_string()
  end

  def format_gwei(_), do: "N/A"

  def calculate_tx_cost(gas_price, gas_limit) do
    case {Integer.parse(gas_price), gas_limit} do
      {{price, _}, limit} when is_integer(limit) ->
        eth_cost = price * limit / 1_000_000_000_000_000_000
        :io_lib.format("~.6f ETH", [eth_cost]) |> to_string()
      _ ->
        "N/A"
    end
  end
end

Helper.print_section("GAS TRACKER EXAMPLE")
IO.puts("This example demonstrates how to track and analyze gas prices using Etherscan lenses.")

# Get current gas oracle data
gas_oracle_result = GasLens.get_gas_oracle()
Helper.print_result("Current Gas Oracle Data", gas_oracle_result)

# Extract gas prices from the result
gas_prices = case gas_oracle_result do
  {:ok, %{result: data}} ->
    %{
      safe: data["SafeGasPrice"],
      propose: data["ProposeGasPrice"],
      fast: data["FastGasPrice"],
      base_fee: data["suggestBaseFee"],
      usage: data["gasUsedRatio"]
    }
  _ ->
    %{safe: "N/A", propose: "N/A", fast: "N/A", base_fee: "N/A", usage: "N/A"}
end

# Display current gas prices in a user-friendly format
IO.puts("\n=== Current Gas Prices (Gwei) ===")
IO.puts("Safe (Low Priority): #{gas_prices.safe}")
IO.puts("Proposed (Standard): #{gas_prices.propose}")
IO.puts("Fast (High Priority): #{gas_prices.fast}")
IO.puts("Suggested Base Fee: #{gas_prices.base_fee}")
IO.puts("Network Utilization: #{gas_prices.usage}")

# Calculate transaction costs for different gas limits
common_gas_limits = [
  %{name: "Simple ETH Transfer", limit: 21000},
  %{name: "ERC20 Token Transfer", limit: 65000},
  %{name: "Uniswap Swap", limit: 180000},
  %{name: "NFT Minting", limit: 200000},
  %{name: "Complex Smart Contract", limit: 500000}
]

IO.puts("\n=== Estimated Transaction Costs ===")
Enum.each(common_gas_limits, fn %{name: name, limit: limit} ->
  IO.puts("\n#{name} (Gas Limit: #{limit})")
  IO.puts("  Low Priority: #{Helper.calculate_tx_cost(gas_prices.safe, limit)}")
  IO.puts("  Standard: #{Helper.calculate_tx_cost(gas_prices.propose, limit)}")
  IO.puts("  High Priority: #{Helper.calculate_tx_cost(gas_prices.fast, limit)}")
end)

# Get gas estimate for confirmation time
gas_prices_to_check = [
  %{name: "1 Gwei", price: "1000000000"},
  %{name: "5 Gwei", price: "5000000000"},
  %{name: "10 Gwei", price: "10000000000"},
  %{name: "50 Gwei", price: "50000000000"},
  %{name: "100 Gwei", price: "100000000000"},
  %{name: "200 Gwei", price: "200000000000"}
]

IO.puts("\n=== Estimated Confirmation Times ===")
Enum.each(gas_prices_to_check, fn %{name: name, price: price} ->
  result = GasLens.get_gas_estimate(%{gasprice: price})

  confirmation_time = case result do
    {:ok, %{result: time}} ->
      seconds = String.to_integer(time)
      cond do
        seconds < 60 -> "#{seconds} seconds"
        seconds < 3600 -> "#{div(seconds, 60)} minutes"
        true -> "#{div(seconds, 3600)} hours #{div(rem(seconds, 3600), 60)} minutes"
      end
    _ ->
      "N/A"
  end

  IO.puts("#{name}: #{confirmation_time}")
end)

# Get historical gas data (Pro API feature)
Helper.print_section("HISTORICAL GAS DATA (PRO API)")

# Define date range for historical data
today = Date.utc_today()
one_week_ago = Date.add(today, -7)

start_date = Date.to_string(one_week_ago)
end_date = Date.to_string(today)

# Get daily average gas price
daily_gas_price_result = GasLens.get_daily_avg_gas_price(%{
  startdate: start_date,
  enddate: end_date,
  sort: "asc"
})
Helper.print_result("Daily Average Gas Price (Last Week)", daily_gas_price_result)

# Get daily gas used
daily_gas_used_result = GasLens.get_daily_gas_used(%{
  startdate: start_date,
  enddate: end_date,
  sort: "asc"
})
Helper.print_result("Daily Gas Used (Last Week)", daily_gas_used_result)

# Get daily average gas limit
daily_gas_limit_result = GasLens.get_daily_avg_gas_limit(%{
  startdate: start_date,
  enddate: end_date,
  sort: "asc"
})
Helper.print_result("Daily Average Gas Limit (Last Week)", daily_gas_limit_result)

# Get daily network utilization
daily_network_util_result = StatsLens.get_daily_network_utilization(%{
  startdate: start_date,
  enddate: end_date,
  sort: "asc"
})
Helper.print_result("Daily Network Utilization (Last Week)", daily_network_util_result)

Helper.print_section("GAS ANALYSIS COMPLETE")
IO.puts("Note: Some features require a Pro API key subscription.")
IO.puts("If you see 'This endpoint requires a Pro API key subscription' errors,")
IO.puts("you need to set ETHERSCAN_API_KEY_PRO=true and use a valid Pro API key.")

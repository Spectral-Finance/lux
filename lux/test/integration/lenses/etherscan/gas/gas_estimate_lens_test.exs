defmodule Lux.Integration.Etherscan.GasEstimateLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.GasEstimate
  alias Lux.Lenses.Etherscan.GasOracle
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch estimated confirmation time for a transaction" do
    # Using a sample gas price of 2 Gwei (2000000000 wei)
    gas_price = 2_000_000_000

    # Always include chainid parameter for v2 API
    assert {:ok, %{result: estimated_seconds}} =
             GasEstimate.focus(%{
               gasprice: gas_price,
               chainid: 1
             })

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0
  end

  test "can fetch estimated confirmation time with current fast gas price" do
    # First, get the current fast gas price from the gas oracle
    # Always include chainid parameter for v2 API
    {:ok, %{result: gas_info}} = GasOracle.focus(%{chainid: 1})

    # Convert the fast gas price from Gwei to wei (1 Gwei = 10^9 wei)
    fast_gas_price_wei = trunc(gas_info.fast_gas_price * 1_000_000_000)

    # Now get the estimated confirmation time for this gas price
    # Always include chainid parameter for v2 API
    assert {:ok, %{result: estimated_seconds}} =
             GasEstimate.focus(%{
               gasprice: fast_gas_price_wei,
               chainid: 1
             })

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0
  end

  test "can fetch estimated confirmation time for a specific chain" do
    # Using a sample gas price of 2 Gwei (2000000000 wei) on Ethereum mainnet
    gas_price = 2_000_000_000
    chain_id = 1

    assert {:ok, %{result: estimated_seconds}} =
             GasEstimate.focus(%{
               gasprice: gas_price,
               chainid: chain_id
             })

    # Verify the result is a number (integer)
    assert is_integer(estimated_seconds)

    # The estimated time should be a positive number
    assert estimated_seconds >= 0
  end

  test "can handle extreme gas price values" do
    # Using an extremely low gas price (0 wei)
    # Note: The API might accept this and return a valid result or an error
    zero_gas_price = 0

    # Always include chainid parameter for v2 API
    result = GasEstimate.focus(%{
      gasprice: zero_gas_price,
      chainid: 1
    })

    case result do
      {:ok, %{result: estimated_seconds}} when is_integer(estimated_seconds) ->
        # If the API accepts the zero gas price, it might return a very high confirmation time
        assert estimated_seconds >= 0

      {:ok, %{result: error_message}} when is_binary(error_message) ->
        # The API might return an error message as the result
        assert String.length(error_message) > 0

      {:error, error} ->
        # Or it might return an error tuple
        assert error != nil
    end

    # Using an extremely high gas price (1000 Gwei = 1000000000000 wei)
    high_gas_price = 1_000_000_000_000

    # Always include chainid parameter for v2 API
    high_result = GasEstimate.focus(%{
      gasprice: high_gas_price,
      chainid: 1
    })

    case high_result do
      {:ok, %{result: estimated_seconds}} when is_integer(estimated_seconds) ->
        # If the API accepts the high gas price, it should return a very low confirmation time
        assert estimated_seconds >= 0

      {:ok, %{result: error_message}} when is_binary(error_message) ->
        # The API might return an error message as the result
        assert String.length(error_message) > 0

      {:error, error} ->
        # Or it might return an error tuple
        assert error != nil
    end
  end
end

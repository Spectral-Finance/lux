defmodule Lux.Integration.Etherscan.BlockByTimestampLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.BlockByTimestamp
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Unix timestamp (January 10, 2020)
  @timestamp 1_578_638_524

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch block number by timestamp with 'before' closest parameter" do
    assert {:ok, %{result: result}} =
             BlockByTimestamp.focus(%{
               timestamp: @timestamp,
               closest: "before",
               chainid: 1
             })

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)

    # The block number should be a string representing an integer
    block_number = result.block_number
    assert is_binary(block_number)
    {block_num, _} = Integer.parse(block_number)
    assert is_integer(block_num)

    # For this timestamp (Jan 10, 2020), the block number should be around 9.2-9.3 million
    assert block_num > 9_000_000
    assert block_num < 9_500_000
  end

  test "can fetch block number by timestamp with 'after' closest parameter" do
    assert {:ok, %{result: result}} =
             BlockByTimestamp.focus(%{
               timestamp: @timestamp,
               closest: "after",
               chainid: 1
             })

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)

    # The block number should be a string representing an integer
    block_number = result.block_number
    assert is_binary(block_number)
    {block_num, _} = Integer.parse(block_number)
    assert is_integer(block_num)

    # For this timestamp (Jan 10, 2020), the block number should be around 9.2-9.3 million
    assert block_num > 9_000_000
    assert block_num < 9_500_000
  end

  test "can fetch block number by timestamp with default parameters" do
    assert {:ok, %{result: result}} =
             BlockByTimestamp.focus(%{
               timestamp: @timestamp,
               chainid: 1
             })

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)

    # The block number should be a string representing an integer
    block_number = result.block_number
    assert is_binary(block_number)
  end
end

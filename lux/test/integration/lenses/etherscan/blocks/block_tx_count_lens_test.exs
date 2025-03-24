defmodule Lux.Integration.Etherscan.BlockTxCountLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.BlockTxCount
  alias Lux.Lenses.Etherscan.BlockByTimestamp
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Block number to check transaction count (from the example in the documentation)
  @block_number 2_165_403

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch transaction count for a specific block" do
    assert {:ok, %{result: result}} =
             BlockTxCount.focus(%{
               blockno: @block_number,
               chainid: 1
             })

    # Verify the result structure
    assert is_map(result)

    # The API might return either a structured response or just a string with the count
    # Handle both cases
    if Map.has_key?(result, :transactions_count) do
      # Structured response
      assert Map.has_key?(result, :block_number)
      assert Map.has_key?(result, :transactions_count)

      # The block number should match what we requested (if present)
      if result.block_number != "" do
        # Convert both to integers for comparison to handle both string and integer responses
        block_num_int = if is_binary(result.block_number), do: String.to_integer(result.block_number), else: result.block_number
        assert block_num_int == @block_number
      end

      # The transaction count should be a non-negative integer
      tx_count = if is_binary(result.transactions_count) do
        {count, _} = Integer.parse(result.transactions_count)
        count
      else
        result.transactions_count
      end

      assert tx_count >= 0

    else
      # Simple string response
      assert is_binary(result)
      {tx_count, _} = Integer.parse(result)
      assert tx_count >= 0
    end
  end

  test "can fetch transaction count for a recent block" do
    # Get a recent block by using a timestamp from a few minutes ago
    timestamp = DateTime.utc_now() |> DateTime.add(-5 * 60, :second) |> DateTime.to_unix()

    {:ok, %{result: recent_block_result}} =
      BlockByTimestamp.focus(%{
        timestamp: timestamp,
        closest: "before",
        chainid: 1
      })

    # Parse the recent block number
    recent_block = String.to_integer(recent_block_result.block_number)

    assert {:ok, %{result: result}} =
             BlockTxCount.focus(%{
               blockno: recent_block,
               chainid: 1
             })

    # Verify we got a result
    assert result != nil
  end

  test "raises error when trying to use with non-Ethereum chain" do
    # This endpoint is only available on Ethereum mainnet (chainid 1)
    assert_raise RuntimeError, "This endpoint is only available on Etherscan (chainId 1)", fn ->
      BlockTxCount.focus(%{
        blockno: @block_number,
        chainid: 137  # Polygon
      })
    end
  end
end

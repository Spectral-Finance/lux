defmodule Lux.Integration.Etherscan.BlockTxCountLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BlockTxCount
  alias Lux.Lenses.Etherscan.BlockByTimestamp
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Block number to check transaction count (from the example in the documentation)
  @block_number 2165403

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthBlockTxCountLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Block Transactions Count API",
      description: "Fetches the number of transactions in a specified block",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "block")
      |> Map.put(:action, "getblocktxnscount")
    end
  end

  test "can fetch transaction count for a specific block" do
    assert {:ok, %{result: result}} =
             RateLimitedAPI.call_standard(BlockTxCount, :focus, [%{
               blockno: @block_number,
               chainid: 1
             }])

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

      # Log the transaction count information for informational purposes
      IO.puts("Block number: #{result.block_number}")
      IO.puts("Transaction count: #{result.transactions_count}")

      # If the response includes additional transaction type counts, log them
      if Map.has_key?(result, :internal_transactions_count) do
        IO.puts("Internal transactions count: #{result.internal_transactions_count}")
      end

      if Map.has_key?(result, :erc20_transactions_count) do
        IO.puts("ERC20 transactions count: #{result.erc20_transactions_count}")
      end

      if Map.has_key?(result, :erc721_transactions_count) do
        IO.puts("ERC721 transactions count: #{result.erc721_transactions_count}")
      end

      if Map.has_key?(result, :erc1155_transactions_count) do
        IO.puts("ERC1155 transactions count: #{result.erc1155_transactions_count}")
      end
    else
      # Simple string response
      assert is_binary(result)
      {tx_count, _} = Integer.parse(result)
      assert tx_count >= 0

      # Log the transaction count information for informational purposes
      IO.puts("Transaction count for block #{@block_number}: #{result}")
    end
  end

  test "can fetch transaction count for a recent block" do
    # Get a recent block by using a timestamp from a few minutes ago
    timestamp = DateTime.utc_now() |> DateTime.add(-5 * 60, :second) |> DateTime.to_unix()

    {:ok, %{result: recent_block_result}} =
      RateLimitedAPI.call_standard(BlockByTimestamp, :focus, [%{
        timestamp: timestamp,
        closest: "before",
        chainid: 1
      }])

    # Parse the recent block number
    recent_block = String.to_integer(recent_block_result.block_number)

    assert {:ok, %{result: result}} =
             RateLimitedAPI.call_standard(BlockTxCount, :focus, [%{
               blockno: recent_block,
               chainid: 1
             }])

    # Verify we got a result
    assert result != nil

    # Log the transaction count information for informational purposes
    IO.puts("Recent block number: #{recent_block}")
    if is_map(result) && Map.has_key?(result, :transactions_count) do
      IO.puts("Transaction count: #{result.transactions_count}")
    else
      IO.puts("Transaction count: #{result}")
    end
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

  test "fails when no auth is provided" do
    # The NoAuthBlockTxCountLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBlockTxCountLens, :focus, [%{
      blockno: @block_number,
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end

defmodule Lux.Integration.Etherscan.BlockRewardLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BlockReward
  alias Lux.Lenses.Etherscan.BlockByTimestamp
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Block number with uncle rewards (from the example in the documentation)
  @block_number 2165403

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthBlockRewardLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Block Reward API",
      description: "Fetches block and uncle rewards for a specific block",
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
      |> Map.put(:action, "getblockreward")
    end
  end

  test "can fetch block and uncle rewards for a specific block" do
    assert {:ok, %{result: result}} =
             RateLimitedAPI.call_standard(BlockReward, :focus, [%{
               blockno: @block_number,
               chainid: 1
             }])

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)
    assert Map.has_key?(result, :timestamp)
    assert Map.has_key?(result, :block_miner)
    assert Map.has_key?(result, :block_reward)
    assert Map.has_key?(result, :uncles)

    # The block number should match what we requested
    assert result.block_number == to_string(@block_number)

    # The block miner should be a valid Ethereum address
    assert String.starts_with?(result.block_miner, "0x")
    assert String.length(result.block_miner) == 42

    # The block reward should be a non-empty string
    assert is_binary(result.block_reward)
    assert String.length(result.block_reward) > 0

    # The uncles should be a list
    assert is_list(result.uncles)

    # If there are uncles, check their structure
    if length(result.uncles) > 0 do
      uncle = List.first(result.uncles)
      assert is_map(uncle)
      assert Map.has_key?(uncle, :miner)
      assert Map.has_key?(uncle, :uncle_position)
      assert Map.has_key?(uncle, :block_reward)

      # The uncle miner should be a valid Ethereum address
      assert String.starts_with?(uncle.miner, "0x")
      assert String.length(uncle.miner) == 42
    end

    # Log the block reward information for informational purposes
    IO.puts("Block number: #{result.block_number}")
    IO.puts("Block miner: #{result.block_miner}")
    IO.puts("Block reward: #{result.block_reward}")
    IO.puts("Number of uncles: #{length(result.uncles)}")
  end

  test "can fetch block rewards for a recent block" do
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
             RateLimitedAPI.call_standard(BlockReward, :focus, [%{
               blockno: recent_block,
               chainid: 1
             }])

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)
    assert Map.has_key?(result, :block_reward)

    # The block number should match what we requested
    assert result.block_number == to_string(recent_block)

    # Log the block reward information for informational purposes
    IO.puts("Recent block number: #{result.block_number}")
    IO.puts("Recent block reward: #{result.block_reward}")
  end

  test "fails when no auth is provided" do
    # The NoAuthBlockRewardLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBlockRewardLens, :focus, [%{
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

defmodule Lux.Integration.Etherscan.BlockByTimestampLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BlockByTimestamp
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Unix timestamp (January 10, 2020)
  @timestamp 1578638524

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthBlockByTimestampLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Block Number by Timestamp API",
      description: "Fetches the block number that was mined at a certain timestamp",
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
      |> Map.put(:action, "getblocknobytime")
    end
  end

  test "can fetch block number by timestamp with 'before' closest parameter" do
    assert {:ok, %{result: result}} =
             RateLimitedAPI.call_standard(BlockByTimestamp, :focus, [%{
               timestamp: @timestamp,
               closest: "before",
               chainid: 1
             }])

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
             RateLimitedAPI.call_standard(BlockByTimestamp, :focus, [%{
               timestamp: @timestamp,
               closest: "after",
               chainid: 1
             }])

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
             RateLimitedAPI.call_standard(BlockByTimestamp, :focus, [%{
               timestamp: @timestamp,
               chainid: 1
             }])

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :block_number)

    # The block number should be a string representing an integer
    block_number = result.block_number
    assert is_binary(block_number)
  end

  test "fails when no auth is provided" do
    # The NoAuthBlockByTimestampLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBlockByTimestampLens, :focus, [%{
      timestamp: @timestamp,
      closest: "before",
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

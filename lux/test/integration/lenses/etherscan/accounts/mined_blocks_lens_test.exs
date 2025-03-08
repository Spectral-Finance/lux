defmodule Lux.Integration.Etherscan.MinedBlocksLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.MinedBlocks
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Address of a known miner/validator (Ethermine pool)
  @miner_address "0xea674fdde714fd979de3edf0f56aa9716b898ec8"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthMinedBlocksLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Mined Blocks API",
      description: "Fetches blocks validated by an Ethereum address",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "getminedblocks")
    end
  end

  test "can fetch mined blocks for an address" do
    assert {:ok, %{result: blocks}} =
             RateLimitedAPI.call_standard(MinedBlocks, :focus, [%{
               address: @miner_address,
               chainid: 1
             }])

    # Verify we got results
    assert is_list(blocks)

    # If there are blocks, check their structure
    if length(blocks) > 0 do
      block = List.first(blocks)

      # Check that the block has the expected fields
      assert Map.has_key?(block, "blockNumber")
      assert Map.has_key?(block, "timeStamp")
      assert Map.has_key?(block, "blockReward")

      # Verify the miner address matches if the field exists
      if Map.has_key?(block, "miner") do
        assert String.downcase(block["miner"]) == String.downcase(@miner_address)
      end
    end
  end

  test "can fetch mined blocks with pagination" do
    assert {:ok, %{result: blocks}} =
             RateLimitedAPI.call_standard(MinedBlocks, :focus, [%{
               address: @miner_address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(blocks) <= 5
  end

  test "can fetch uncle blocks" do
    assert {:ok, %{result: blocks}} =
             RateLimitedAPI.call_standard(MinedBlocks, :focus, [%{
               address: @miner_address,
               chainid: 1,
               blocktype: "uncles"
             }])

    # We may or may not get uncle blocks, but the request should succeed
    assert is_list(blocks)
  end

  test "fails when no auth is provided" do
    # The NoAuthMinedBlocksLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthMinedBlocksLens, :focus, [%{
      address: @miner_address,
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

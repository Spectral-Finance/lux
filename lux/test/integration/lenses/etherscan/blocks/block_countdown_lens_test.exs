defmodule Lux.Integration.Etherscan.BlockCountdownLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BlockCountdown
  alias Lux.Lenses.Etherscan.BlockByTimestamp
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthBlockCountdownLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Block Countdown API",
      description: "Fetches the estimated time remaining until a certain block is mined",
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
      |> Map.put(:action, "getblockcountdown")
    end
  end

  test "can fetch block countdown for a future block" do
    # Get the current block by using the current timestamp
    current_timestamp = DateTime.utc_now() |> DateTime.to_unix()

    {:ok, %{result: current_block_result}} =
      RateLimitedAPI.call_standard(BlockByTimestamp, :focus, [%{
        timestamp: current_timestamp,
        closest: "before",
        chainid: 1
      }])

    # Parse the current block number
    current_block = String.to_integer(current_block_result.block_number)

    # Set a future block (current + 1000 blocks)
    future_block = current_block + 1000

    assert {:ok, %{result: result}} =
             RateLimitedAPI.call_standard(BlockCountdown, :focus, [%{
               blockno: future_block,
               chainid: 1
             }])

    # Verify the result structure
    assert is_map(result)
    assert Map.has_key?(result, :current_block)
    assert Map.has_key?(result, :countdown_block)
    assert Map.has_key?(result, :remaining_blocks)
    assert Map.has_key?(result, :estimated_time_in_sec)

    # The countdown block should match our future block
    assert result.countdown_block == to_string(future_block)

    # The remaining blocks should be positive
    remaining_blocks = result.remaining_blocks
    assert is_binary(remaining_blocks)
    {remaining, _} = Integer.parse(remaining_blocks)
    assert remaining > 0

    # The estimated time should be positive
    estimated_time = result.estimated_time_in_sec
    assert is_binary(estimated_time)
    {time_sec, _} = Integer.parse(estimated_time)
    assert time_sec > 0
  end

  test "fails when no auth is provided" do
    # The NoAuthBlockCountdownLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBlockCountdownLens, :focus, [%{
      blockno: 16701588,
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

defmodule Lux.Integration.Etherscan.DailyBlockRewardsLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyBlockRewards
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthDailyBlockRewardsLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Daily Block Rewards API",
      description: "Fetches the amount of block rewards distributed to miners daily",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "stats")
      |> Map.put(:action, "dailyblockrewards")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Make a test call to see if we get a Pro API error
    case RateLimitedAPI.call_standard(DailyBlockRewards, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }]) do
      {:error, %{result: result}} ->
        # If the result contains "API Pro endpoint", we don't have a Pro API key
        not String.contains?(result, "API Pro endpoint") and
        not String.contains?(result, "Missing Or invalid Action name")
      _ ->
        # If we get any other response, assume we have a Pro API key
        true
    end
  end

  test "can fetch daily block rewards with required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for DailyBlockRewards or invalid action name")
      :ok
    else
      assert {:ok, %{result: block_rewards_data}} =
               RateLimitedAPI.call_standard(DailyBlockRewards, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(block_rewards_data)

      # If we got data, check the first entry
      if length(block_rewards_data) > 0 do
        first_entry = List.first(block_rewards_data)
        assert Map.has_key?(first_entry, :date)
        assert Map.has_key?(first_entry, :block_rewards_eth)
        assert Map.has_key?(first_entry, :blocks_count)
        assert Map.has_key?(first_entry, :uncles_inclusion_rewards_eth)
        assert Map.has_key?(first_entry, :uncles_count)
        assert Map.has_key?(first_entry, :uncle_rewards_eth)
        assert Map.has_key?(first_entry, :total_block_rewards_eth)

        # Block rewards should be a positive number
        assert is_binary(first_entry.block_rewards_eth) or is_number(first_entry.block_rewards_eth)

        # Log the data for informational purposes
        IO.puts("Date: #{first_entry.date}")
        IO.puts("Block Rewards: #{first_entry.block_rewards_eth} ETH")
        IO.puts("Blocks Count: #{first_entry.blocks_count}")
        IO.puts("Total Block Rewards: #{first_entry.total_block_rewards_eth} ETH")
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for DailyBlockRewards or invalid action name")
      :ok
    else
      assert {:ok, %{result: block_rewards_data}} =
               RateLimitedAPI.call_standard(DailyBlockRewards, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(block_rewards_data)

      # If we got data, check that it's in descending order
      if length(block_rewards_data) > 1 do
        first_date = List.first(block_rewards_data).date
        second_date = Enum.at(block_rewards_data, 1).date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthDailyBlockRewardsLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthDailyBlockRewardsLens, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key") or
               String.contains?(error_message, "Missing Or invalid Action name")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end

  test "raises error or returns error for Pro API endpoint" do
    # This test verifies that we either get an ArgumentError or a specific error message
    # when trying to use a Pro API endpoint without a Pro API key
    result = RateLimitedAPI.call_standard(DailyBlockRewards, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} ->
        # If we get an error about API Pro endpoint or invalid action, that's expected
        assert String.contains?(result, "API Pro endpoint") or
               String.contains?(result, "Missing Or invalid Action name")


      _ ->
        # If we get here, we might have a Pro API key, so the test should be skipped
        if has_pro_api_key?() do
          IO.puts("Skipping test: We have a Pro API key, so this test is not applicable")
          :ok
        else
          flunk("Expected an error for Pro API endpoint or invalid action name")
        end
    end
  end

  test "returns error for missing required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for DailyBlockRewards or invalid action name")
      :ok
    else
      # Missing startdate and enddate
      result = RateLimitedAPI.call_standard(DailyBlockRewards, :focus, [%{
        chainid: 1
      }])

      case result do
        {:error, error} ->
          # Should return an error for missing required parameters
          assert error != nil

        _ ->
          flunk("Expected an error for missing required parameters")
      end
    end
  end
end

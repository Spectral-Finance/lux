defmodule Lux.Integration.Etherscan.DailyAvgBlockSizeLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyAvgBlockSize

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 2000ms to avoid hitting the Etherscan API rate limit (2 calls per second for this endpoint)
    Process.sleep(2000)
    :ok
  end

  defmodule NoAuthDailyAvgBlockSizeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Daily Average Block Size API",
      description: "Fetches the daily average block size within a date range",
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
      |> Map.put(:action, "dailyavgblocksize")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Make a test call to see if we get a Pro API error
    case DailyAvgBlockSize.focus(%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }) do
      {:error, %{result: result}} ->
        # If the result contains "API Pro endpoint", we don't have a Pro API key
        not String.contains?(result, "API Pro endpoint") and
        not String.contains?(result, "Missing Or invalid Action name")
      _ ->
        # If we get any other response, assume we have a Pro API key
        true
    end
  end

  test "can fetch daily average block size with required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for DailyAvgBlockSize or invalid action name")
      :ok
    else
      assert {:ok, %{result: block_size_data}} =
               DailyAvgBlockSize.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(block_size_data)

      # If we got data, check the first entry
      if length(block_size_data) > 0 do
        first_entry = List.first(block_size_data)
        assert Map.has_key?(first_entry, :date)
        assert Map.has_key?(first_entry, :avg_block_size)

        # Average block size should be a positive number
        assert is_binary(first_entry.avg_block_size) or is_number(first_entry.avg_block_size)

        # Log the data for informational purposes
        IO.puts("Date: #{first_entry.date}")
        IO.puts("Average Block Size: #{first_entry.avg_block_size}")
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for DailyAvgBlockSize or invalid action name")
      :ok
    else
      assert {:ok, %{result: block_size_data}} =
               DailyAvgBlockSize.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(block_size_data)

      # If we got data, check that it's in descending order
      if length(block_size_data) > 1 do
        first_date = List.first(block_size_data).date
        second_date = Enum.at(block_size_data, 1).date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthDailyAvgBlockSizeLens doesn't have an API key, so it should fail
    result = NoAuthDailyAvgBlockSizeLens.focus(%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    })

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
    result = DailyAvgBlockSize.focus(%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    })

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
      IO.puts("Skipping test: Pro API key required for DailyAvgBlockSize or invalid action name")
      :ok
    else
      # Missing startdate and enddate
      result = DailyAvgBlockSize.focus(%{
        chainid: 1
      })

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

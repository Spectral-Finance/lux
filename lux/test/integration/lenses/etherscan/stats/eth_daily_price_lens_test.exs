defmodule Lux.Integration.Etherscan.EthDailyPriceLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.EthDailyPrice
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthEthDailyPriceLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan ETH Daily Price API",
      description: "Fetches the historical price of 1 ETH",
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
      |> Map.put(:action, "ethdailyprice")
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Make a test call to see if we get a Pro API error
    case RateLimitedAPI.call_standard(EthDailyPrice, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }]) do
      {:error, %{result: result}} ->
        # If the result contains "API Pro endpoint", we don't have a Pro API key
        not String.contains?(result, "API Pro endpoint")
      _ ->
        # If we get any other response, assume we have a Pro API key
        true
    end
  end

  test "can fetch ETH daily price with required parameters" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: price_data, eth_daily_price: price_data}} =
               RateLimitedAPI.call_standard(EthDailyPrice, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(price_data)

      # If we got data, check the first entry
      if length(price_data) > 0 do
        first_entry = List.first(price_data)
        assert Map.has_key?(first_entry, :utc_date)
        assert Map.has_key?(first_entry, :eth_usd)
        assert Map.has_key?(first_entry, :eth_btc)

        # Price values should be positive numbers
        assert is_number(first_entry.eth_usd)
        assert first_entry.eth_usd > 0
        assert is_number(first_entry.eth_btc)
        assert first_entry.eth_btc > 0
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      assert {:ok, %{result: price_data}} =
               RateLimitedAPI.call_standard(EthDailyPrice, :focus, [%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               }])

      # Verify the structure of the response
      assert is_list(price_data)

      # If we got data, check that it's in descending order
      if length(price_data) > 1 do
        first_date = List.first(price_data).utc_date
        second_date = Enum.at(price_data, 1).utc_date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthEthDailyPriceLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthEthDailyPriceLens, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
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

  test "raises error or returns error for Pro API endpoint" do
    # This test verifies that we either get an ArgumentError or a specific error message
    # when trying to use a Pro API endpoint without a Pro API key
    result = RateLimitedAPI.call_standard(EthDailyPrice, :focus, [%{
      startdate: @start_date,
      enddate: @end_date,
      chainid: 1
    }])

    case result do
      {:error, %{result: result}} ->
        # If we get an error about API Pro endpoint, that's expected
        assert String.contains?(result, "API Pro endpoint")

      _ ->
        # If we get here, we might have a Pro API key, so the test should be skipped
        if has_pro_api_key?() do
          :ok
        else
          flunk("Expected an error for Pro API endpoint")
        end
    end
  end

  test "returns error for missing required parameters" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      :ok
    else
      # Missing startdate and enddate
      result = RateLimitedAPI.call_standard(EthDailyPrice, :focus, [%{
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

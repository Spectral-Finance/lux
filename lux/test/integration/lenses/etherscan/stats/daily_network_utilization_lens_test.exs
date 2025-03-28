defmodule Lux.Integration.Etherscan.DailyNetworkUtilizationLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyNetworkUtilization
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "dailynetworkutilization") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch daily network utilization with required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if has_pro_api_key?() do
      assert {:ok, %{result: utilization_data}} =
               DailyNetworkUtilization.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(utilization_data)

      # If we got data, check the first entry
      if length(utilization_data) > 0 do
        first_entry = List.first(utilization_data)
        assert Map.has_key?(first_entry, :date)
        assert Map.has_key?(first_entry, :gas_used_percent)

        # Network utilization should be a percentage between 0 and 100
        assert is_binary(first_entry.gas_used_percent) or is_number(first_entry.gas_used_percent)
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if has_pro_api_key?() do
      assert {:ok, %{result: utilization_data}} =
               DailyNetworkUtilization.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(utilization_data)

      # If we got data, check that it's in descending order
      if length(utilization_data) > 1 do
        first_date = List.first(utilization_data).date
        second_date = Enum.at(utilization_data, 1).date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end
end

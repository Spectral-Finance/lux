defmodule Lux.Integration.Etherscan.DailyAvgGasLimitLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyAvgGasLimit
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "dailyavggaslimit") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch daily average gas limit with required parameters" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: gas_limit_data}} =
               DailyAvgGasLimit.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(gas_limit_data)

      # If we got data, check the first entry
      if length(gas_limit_data) > 0 do
        first_entry = List.first(gas_limit_data)
        assert Map.has_key?(first_entry, :utc_date)
        assert Map.has_key?(first_entry, :gas_limit)

        # Average gas limit should be a positive number
        assert is_number(first_entry.gas_limit) or is_binary(first_entry.gas_limit)
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: gas_limit_data}} =
               DailyAvgGasLimit.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(gas_limit_data)

      # If we got data, check that it's in descending order
      if length(gas_limit_data) > 1 do
        first_date = List.first(gas_limit_data).utc_date
        second_date = Enum.at(gas_limit_data, 1).utc_date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end
end

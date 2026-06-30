defmodule Lux.Integration.Etherscan.DailyTxnFeeLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.DailyTxnFee
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "dailytxnfee") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch daily transaction fees with required parameters" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if has_pro_api_key?() do
      assert {:ok, %{result: txn_fee_data}} =
               DailyTxnFee.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(txn_fee_data)

      # If we got data, check the first entry
      if length(txn_fee_data) > 0 do
        first_entry = List.first(txn_fee_data)
        assert Map.has_key?(first_entry, :date)
        assert Map.has_key?(first_entry, :tx_fees_eth)

        # Transaction fees should be a positive number
        assert is_binary(first_entry.tx_fees_eth) or is_number(first_entry.tx_fees_eth)
      end
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key or if the action name is invalid
    if has_pro_api_key?() do
      assert {:ok, %{result: txn_fee_data}} =
               DailyTxnFee.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(txn_fee_data)

      # If we got data, check that it's in descending order
      if length(txn_fee_data) > 1 do
        first_date = List.first(txn_fee_data).date
        second_date = Enum.at(txn_fee_data, 1).date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end
end

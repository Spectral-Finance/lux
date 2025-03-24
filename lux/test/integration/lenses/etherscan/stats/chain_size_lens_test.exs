defmodule Lux.Integration.Etherscan.ChainSizeLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.ChainSize
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example date range (one month)
  @start_date "2023-01-01"
  @end_date "2023-01-31"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "chainsize") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch chain size data with required parameters" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: chain_size_data, chain_size: chain_size_data}} =
               ChainSize.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(chain_size_data)

      # If we got data, check the first entry
      if length(chain_size_data) > 0 do
        first_entry = List.first(chain_size_data)
        assert Map.has_key?(first_entry, :utc_date)
        assert Map.has_key?(first_entry, :block_number)
        assert Map.has_key?(first_entry, :chain_size_bytes)

        # Chain size should be a large number (more than 100 GB in bytes)
        assert is_integer(first_entry.chain_size_bytes)
        assert first_entry.chain_size_bytes > 100 * 1024 * 1024 * 1024 # More than 100 GB
      end
    end
  end

  test "can fetch chain size data with all parameters" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: chain_size_data}} =
               ChainSize.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 clienttype: "geth",
                 syncmode: "default",
                 sort: "asc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(chain_size_data)
    end
  end

  test "can specify different sort order" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: chain_size_data}} =
               ChainSize.focus(%{
                 startdate: @start_date,
                 enddate: @end_date,
                 sort: "desc",
                 chainid: 1
               })

      # Verify the structure of the response
      assert is_list(chain_size_data)

      # If we got data, check that it's in descending order
      if length(chain_size_data) > 1 do
        first_date = List.first(chain_size_data).utc_date
        second_date = Enum.at(chain_size_data, 1).utc_date

        # In descending order, the first date should be later than the second date
        assert first_date >= second_date
      end
    end
  end
end

defmodule Lux.Integration.Etherscan.TokenHolderListLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenHolderList
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("token", "tokenholderlist") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch token holder list" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: holders, token_holders: holders}} =
               TokenHolderList.focus(%{
                 contractaddress: @token_contract,
                 chainid: 1
               })

      # Verify the holders list structure
      assert is_list(holders)
      assert length(holders) > 0

      # Check the first holder's structure
      first_holder = List.first(holders)
      assert Map.has_key?(first_holder, :address)
      assert Map.has_key?(first_holder, :quantity)
      assert Map.has_key?(first_holder, :share)
    end
  end

  test "can fetch token holder list with pagination" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      # Using a small offset to test pagination
      offset = 5

      assert {:ok, %{result: holders}} =
               TokenHolderList.focus(%{
                 contractaddress: @token_contract,
                 page: 1,
                 offset: offset,
                 chainid: 1
               })

      # Verify the holders list structure
      assert is_list(holders)
      assert length(holders) <= offset
    end
  end
end

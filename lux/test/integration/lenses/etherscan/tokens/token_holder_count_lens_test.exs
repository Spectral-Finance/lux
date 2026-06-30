defmodule Lux.Integration.Etherscan.TokenHolderCountLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenHolderCount
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("token", "tokenholdercount") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch token holder count" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: count, holder_count: count}} =
               TokenHolderCount.focus(%{
                 contractaddress: @token_contract,
                 chainid: 1
               })

      # Verify the count is a valid string representing a number
      assert is_binary(count)
      {count_value, _} = Integer.parse(count)
      assert count_value > 0
    end
  end
end

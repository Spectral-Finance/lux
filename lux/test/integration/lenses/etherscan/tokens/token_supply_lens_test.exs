defmodule Lux.Integration.Etherscan.TokenSupplyLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenSupply
  import Lux.Integration.Etherscan.RateLimitedAPI
  alias Lux.Lenses.Etherscan.Base

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "tokensupply") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch total supply for an ERC-20 token" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      assert {:ok, %{result: supply, token_supply: supply}} =
               TokenSupply.focus(%{
                 contractaddress: @token_contract,
                 chainid: 1
               })

      # Verify the supply is a valid string representing a number
      assert is_binary(supply)
      {supply_value, _} = Integer.parse(supply)
      assert supply_value > 0
    end
  end
end

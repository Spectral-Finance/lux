defmodule Lux.Integration.Etherscan.TokenSupplyHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenSupplyHistory
  import Lux.Integration.Etherscan.RateLimitedAPI
  alias Lux.Lenses.Etherscan.Base

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Block number to check (Ethereum block from 2019)
  @block_number 8_000_000

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  # Helper function to check if we're being rate limited
  defp rate_limited?(result) do
    case result do
      {:error, %{result: "Max rate limit reached"}} -> true
      {:error, %{message: message}} when is_binary(message) ->
        String.contains?(message, "rate limit")
      _ -> false
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    case Base.check_pro_endpoint("stats", "tokensupplyhistory") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch historical token supply at a specific block" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = TokenSupplyHistory.focus(%{
        contractaddress: @token_contract,
        blockno: @block_number,
        chainid: 1
      })

      case result do
        {:ok, %{result: supply, token_supply: supply}} ->
          # Verify the supply is a valid string representing a number
          assert is_binary(supply)
          {supply_value, _} = Integer.parse(supply)
          assert supply_value > 0

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch historical token supply: #{inspect(error)}")
          end
      end
    end
  end
end

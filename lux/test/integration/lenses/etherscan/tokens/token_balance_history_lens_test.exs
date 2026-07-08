defmodule Lux.Integration.Etherscan.TokenBalanceHistoryLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenBalanceHistory
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"
  # Example address that holds LINK tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"
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
    case Base.check_pro_endpoint("account", "tokenbalancehistory") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch historical token balance for an address at a specific block" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = TokenBalanceHistory.focus(%{
        contractaddress: @token_contract,
        address: @token_holder,
        blockno: @block_number,
        chainid: 1
      })

      case result do
        {:ok, %{result: balance, token_balance: balance}} ->
          # Verify the balance is a valid string representing a number
          assert is_binary(balance)

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch historical token balance: #{inspect(error)}")
          end
      end
    end
  end
end

defmodule Lux.Integration.Etherscan.AddressTokenBalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.AddressTokenBalance
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example address that holds multiple tokens (Binance)
  @token_holder "0x28c6c06298d514db089934071355e5743bf21d60"

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
    case Base.check_pro_endpoint("account", "addresstokenbalance") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch token balances for an address" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = AddressTokenBalance.focus(%{
        address: @token_holder,
        chainid: 1
      })

      case result do
        {:ok, %{result: tokens, token_balances: tokens}} ->
          # Verify the tokens list structure
          assert is_list(tokens)

          # If tokens are found, check their structure
          if length(tokens) > 0 do
            first_token = List.first(tokens)
            assert Map.has_key?(first_token, :token_address)
            assert Map.has_key?(first_token, :token_name)
            assert Map.has_key?(first_token, :token_symbol)
            assert Map.has_key?(first_token, :token_decimals)
            assert Map.has_key?(first_token, :token_quantity)
            
            # Verify token data is valid
            assert is_binary(first_token.token_name)
            assert is_binary(first_token.token_symbol)
            assert is_binary(first_token.token_quantity)
          end

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch token balances: #{inspect(error)}")
          end
      end
    end
  end

  test "can fetch token balances with pagination" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      # Using a small offset to test pagination
      offset = 5

      result = AddressTokenBalance.focus(%{
        address: @token_holder,
        page: 1,
        offset: offset,
        chainid: 1
      })

      case result do
        {:ok, %{result: tokens}} ->
          # Verify the tokens list structure
          assert is_list(tokens)
          assert length(tokens) <= offset

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch token balances with pagination: #{inspect(error)}")
          end
      end
    end
  end
end

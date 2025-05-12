defmodule Lux.Integration.Etherscan.TokenInfoLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TokenInfo
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example ERC-20 token contract address (LINK token)
  @token_contract "0x514910771af9ca656af840dff83e8264ecf986ca"

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
    case Base.check_pro_endpoint("token", "tokeninfo") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch token info" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = TokenInfo.focus(%{
        contractaddress: @token_contract,
        chainid: 1
      })

      case result do
        {:ok, %{result: token_info, token_info: token_info}} ->
          # Verify the token info structure
          assert is_list(token_info)
          assert length(token_info) > 0

          # Check the first token info's structure
          token = List.first(token_info)
          assert Map.has_key?(token, :contract_address)
          assert Map.has_key?(token, :token_name)
          assert Map.has_key?(token, :symbol)
          assert Map.has_key?(token, :token_type)

          # Verify token data is valid
          assert is_binary(token.token_name)
          assert is_binary(token.symbol)
          assert is_binary(token.token_type)
          assert Map.has_key?(token, :total_supply)

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch token info: #{inspect(error)}")
          end
      end
    end
  end
end

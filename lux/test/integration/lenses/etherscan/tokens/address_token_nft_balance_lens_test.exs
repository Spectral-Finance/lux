defmodule Lux.Integration.Etherscan.AddressTokenNFTBalanceLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.AddressTokenNFTBalance
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example address that holds NFTs
  @nft_holder "0x6b52e83941eb10f9c613c395a834457559a80114"

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
    case Base.check_pro_endpoint("account", "addresstokennftbalance") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch NFT balances for an address" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = AddressTokenNFTBalance.focus(%{
        address: @nft_holder,
        chainid: 1
      })

      case result do
        {:ok, %{result: nfts, nft_balances: nfts}} ->
          # Verify the NFTs list structure
          assert is_list(nfts)

          # If NFTs are found, check their structure
          if length(nfts) > 0 do
            first_nft = List.first(nfts)
            assert Map.has_key?(first_nft, :contract_address)
            assert Map.has_key?(first_nft, :name)
            assert Map.has_key?(first_nft, :symbol)
            assert Map.has_key?(first_nft, :quantity)
            assert Map.has_key?(first_nft, :token_id)
            
            # Verify NFT data is valid
            assert is_binary(first_nft.name)
            assert is_binary(first_nft.symbol)
            assert is_binary(first_nft.quantity) || is_number(first_nft.quantity)
          end

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch NFT balances: #{inspect(error)}")
          end
      end
    end
  end

  test "can fetch NFT balances with pagination" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      # Using a small offset to test pagination
      offset = 5

      result = AddressTokenNFTBalance.focus(%{
        address: @nft_holder,
        page: 1,
        offset: offset,
        chainid: 1
      })

      case result do
        {:ok, %{result: nfts}} ->
          # Verify the NFTs list structure
          assert is_list(nfts)
          assert length(nfts) <= offset

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch NFT balances with pagination: #{inspect(error)}")
          end
      end
    end
  end
end

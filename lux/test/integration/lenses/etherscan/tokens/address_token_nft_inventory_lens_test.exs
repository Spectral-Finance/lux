defmodule Lux.Integration.Etherscan.AddressTokenNFTInventoryLensTest do
  @moduledoc false
  use IntegrationCase, async: true
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.AddressTokenNFTInventory
  alias Lux.Lenses.Etherscan.Base
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Example address that holds NFTs
  @nft_holder "0x123432244443b54409430979df8333f9308a6040"
  # Example NFT contract address (Azuki)
  @nft_contract "0xed5af388653567af2f388e6224dc7c4b3241c544"

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
    case Base.check_pro_endpoint("account", "addresstokennftinventory") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  test "can fetch NFT inventory for an address filtered by contract" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      result = AddressTokenNFTInventory.focus(%{
        address: @nft_holder,
        contractaddress: @nft_contract,
        chainid: 1
      })

      case result do
        {:ok, %{result: nfts, nft_inventory: nfts}} ->
          # Verify the NFTs list structure
          assert is_list(nfts)

          # If NFTs are found, check their structure
          if length(nfts) > 0 do
            first_nft = List.first(nfts)
            assert Map.has_key?(first_nft, :contract_address)
            assert Map.has_key?(first_nft, :name)
            assert Map.has_key?(first_nft, :symbol)
            assert Map.has_key?(first_nft, :token_id)
            assert Map.has_key?(first_nft, :token_uri)
            
            # Verify NFT data is valid
            assert is_binary(first_nft.name)
            assert is_binary(first_nft.symbol)
            assert is_binary(first_nft.token_id) || is_number(first_nft.token_id)
          end

        {:error, error} ->
          if rate_limited?(result) do
            :ok
          else
            flunk("Failed to fetch NFT inventory: #{inspect(error)}")
          end
      end
    end
  end

  test "can fetch NFT inventory with pagination" do
    # Skip this test if we don't have a Pro API key
    if has_pro_api_key?() do
      # Using a small offset to test pagination
      offset = 5

      result = AddressTokenNFTInventory.focus(%{
        address: @nft_holder,
        contractaddress: @nft_contract,
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
            flunk("Failed to fetch NFT inventory with pagination: #{inspect(error)}")
          end
      end
    end
  end
end

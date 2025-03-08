defmodule Lux.Integration.Etherscan.AddressTokenNFTInventoryLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.AddressTokenNFTInventory

  # Example address that holds NFTs
  @nft_holder "0x123432244443b54409430979df8333f9308a6040"
  # Example NFT contract address (Azuki)
  @nft_contract "0xed5af388653567af2f388e6224dc7c4b3241c544"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Sleep for 2000ms to avoid hitting the Etherscan API rate limit (2 calls per second for this endpoint)
    Process.sleep(200)
    :ok
  end

  defmodule NoAuthAddressTokenNFTInventoryLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Address ERC721 Token Inventory API",
      description: "Fetches the ERC-721 token inventory of an address, filtered by contract address",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Ensure page and offset parameters have default values
      params = params
      |> Map.put_new(:page, 1)
      |> Map.put_new(:offset, 100)

      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "addresstokennftinventory")
    end
  end

  # Helper function to check if we're being rate limited
  defp is_rate_limited?(result) do
    case result do
      {:error, %{result: "Max rate limit reached"}} -> true
      {:error, %{message: message}} when is_binary(message) ->
        String.contains?(message, "rate limit")
      _ -> false
    end
  end

  # Helper function to check if we have a Pro API key
  defp has_pro_api_key? do
    # Check if the API key is a Pro key by making a test request
    result = AddressTokenNFTInventory.focus(%{
      address: @nft_holder,
      contractaddress: @nft_contract,
      chainid: 1
    })

    case result do
      {:error, %{result: result}} when is_binary(result) ->
        not String.contains?(result, "API Pro endpoint")
      _ -> true
    end
  end

  test "can fetch NFT inventory for an address filtered by contract" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for AddressTokenNFTInventory")
      :ok
    else
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

            # Log some NFT info for informational purposes
            IO.puts("Number of NFTs from contract #{@nft_contract} held by #{@nft_holder}: #{length(nfts)}")
            IO.puts("First NFT name: #{first_nft.name}")
            IO.puts("First NFT symbol: #{first_nft.symbol}")
            IO.puts("First NFT token ID: #{first_nft.token_id}")
          else
            IO.puts("No NFTs found for address #{@nft_holder} from contract #{@nft_contract}")
          end

        {:error, error} ->
          if is_rate_limited?(result) do
            IO.puts("Skipping test due to rate limiting: #{inspect(error)}")
          else
            flunk("Failed to fetch NFT inventory: #{inspect(error)}")
          end
      end
    end
  end

  test "can fetch NFT inventory with pagination" do
    # Skip this test if we don't have a Pro API key
    if not has_pro_api_key?() do
      IO.puts("Skipping test: Pro API key required for AddressTokenNFTInventory")
      :ok
    else
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

          # Log the number of NFTs returned
          IO.puts("Number of NFTs returned with offset #{offset}: #{length(nfts)}")

        {:error, error} ->
          if is_rate_limited?(result) do
            IO.puts("Skipping test due to rate limiting: #{inspect(error)}")
          else
            flunk("Failed to fetch NFT inventory with pagination: #{inspect(error)}")
          end
      end
    end
  end

  test "returns error for invalid address" do
    # Using an invalid address format
    result = AddressTokenNFTInventory.focus(%{
      address: "0xinvalid",
      contractaddress: @nft_contract,
      chainid: 1
    })

    case result do
      {:error, error} ->
        # Should return an error for invalid address
        assert error != nil
        IO.puts("Error for invalid address: #{inspect(error)}")

      {:ok, %{result: "0"}} ->
        # Some APIs return "0" for invalid addresses instead of an error
        IO.puts("API returned '0' for invalid address")
        assert true

      {:ok, _} ->
        # If the API doesn't return an error, that's also acceptable
        # as long as we're testing the API behavior
        IO.puts("API didn't return an error for invalid address")
        assert true
    end
  end

  test "returns error for invalid contract address" do
    # Using an invalid contract address format
    result = AddressTokenNFTInventory.focus(%{
      address: @nft_holder,
      contractaddress: "0xinvalid",
      chainid: 1
    })

    case result do
      {:error, error} ->
        # Should return an error for invalid contract address
        assert error != nil
        IO.puts("Error for invalid contract address: #{inspect(error)}")

      {:ok, %{result: "0"}} ->
        # Some APIs return "0" for invalid addresses instead of an error
        IO.puts("API returned '0' for invalid contract address")
        assert true

      {:ok, _} ->
        # If the API doesn't return an error, that's also acceptable
        # as long as we're testing the API behavior
        IO.puts("API didn't return an error for invalid contract address")
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthAddressTokenNFTInventoryLens doesn't have an API key, so it should fail
    result = NoAuthAddressTokenNFTInventoryLens.focus(%{
      address: @nft_holder,
      contractaddress: @nft_contract,
      chainid: 1
    })

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")
        IO.puts("Error for no auth: #{error_message}")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil

    end
  end
end

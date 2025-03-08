defmodule Lux.Integration.Etherscan.TokenNftAddressTxLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TokenNftAddressTx
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Address with NFT transfers
  @address "0x6975be450864c02b4613023c2152ee0743572325"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenNftAddressTxLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TokenNftAddressTx",
      description: "Retrieves ERC-721 NFT token transfers for a specific wallet address",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "account")
      |> Map.put(:action, "tokennfttx")
    end
  end

  test "can fetch NFT transfers for an address" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenNftAddressTx, :focus, [%{
               address: @address,
               chainid: 1
             }])

    # Verify we got results
    assert is_list(transfers)

    # If there are transfers, check their structure
    if length(transfers) > 0 do
      transfer = List.first(transfers)

      # Check that the transfer has the expected fields
      assert Map.has_key?(transfer, "blockNumber")
      assert Map.has_key?(transfer, "timeStamp")
      assert Map.has_key?(transfer, "contractAddress")
      assert Map.has_key?(transfer, "from")
      assert Map.has_key?(transfer, "to")
      assert Map.has_key?(transfer, "tokenID")
      assert Map.has_key?(transfer, "tokenName")
      assert Map.has_key?(transfer, "tokenSymbol")

      # Verify the address is involved in the transfer
      address_downcase = String.downcase(@address)
      assert String.downcase(transfer["from"]) == address_downcase ||
             String.downcase(transfer["to"]) == address_downcase
    end
  end

  test "can fetch NFT transfers with pagination" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenNftAddressTx, :focus, [%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenNftAddressTxLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenNftAddressTxLens, :focus, [%{
      address: @address,
      chainid: 1
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        assert String.contains?(error_message, "Missing/Invalid API Key")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end
end 
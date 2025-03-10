defmodule Lux.Integration.Etherscan.TokenErc1155AddressTxLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TokenErc1155AddressTx
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Address with ERC-1155 token transfers
  @address "0x83f564d180b58ad9a02a449105568189ee7de8cb"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenErc1155AddressTxLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TokenErc1155AddressTx",
      description: "Retrieves ERC-1155 token transfers for a specific wallet address",
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
      |> Map.put(:action, "token1155tx")
    end
  end

  test "can fetch ERC-1155 transfers for an address" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenErc1155AddressTx, :focus, [%{
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
      assert Map.has_key?(transfer, "tokenValue")

      # Verify the address is involved in the transfer
      address_downcase = String.downcase(@address)
      assert String.downcase(transfer["from"]) == address_downcase ||
             String.downcase(transfer["to"]) == address_downcase
    end
  end

  test "can fetch ERC-1155 transfers with pagination" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenErc1155AddressTx, :focus, [%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenErc1155AddressTxLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenErc1155AddressTxLens, :focus, [%{
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
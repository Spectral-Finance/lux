defmodule Lux.Integration.Etherscan.TokenAddressTxLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TokenAddressTx
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Address with ERC-20 token transfers
  @address "0x4e83362442b8d1bec281594cea3050c8eb01311c"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenAddressTxLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TokenAddressTx",
      description: "Retrieves ERC-20 token transfers for a specific wallet address",
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
      |> Map.put(:action, "tokentx")
    end
  end

  test "can fetch ERC-20 transfers for an address" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenAddressTx, :focus, [%{
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
      assert Map.has_key?(transfer, "value")
      assert Map.has_key?(transfer, "tokenName")
      assert Map.has_key?(transfer, "tokenSymbol")
      assert Map.has_key?(transfer, "tokenDecimal")

      # Verify the address is involved in the transfer
      address_downcase = String.downcase(@address)
      assert String.downcase(transfer["from"]) == address_downcase ||
             String.downcase(transfer["to"]) == address_downcase
    end
  end

  test "can fetch ERC-20 transfers with pagination" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenAddressTx, :focus, [%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenAddressTxLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenAddressTxLens, :focus, [%{
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
defmodule Lux.Integration.Etherscan.TokenContractTxLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TokenContractTx
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # MKR token contract address
  @contract_address "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTokenContractTxLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TokenContractTx",
      description: "Retrieves all ERC-20 token transfers for a specific token contract",
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

  test "can fetch ERC-20 transfers for a contract address" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenContractTx, :focus, [%{
               contractaddress: @contract_address,
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

      # Verify the contract address matches
      assert String.downcase(transfer["contractAddress"]) == String.downcase(@contract_address)
    end
  end

  test "can fetch ERC-20 transfers with pagination" do
    assert {:ok, %{result: transfers}} =
             RateLimitedAPI.call_standard(TokenContractTx, :focus, [%{
               contractaddress: @contract_address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTokenContractTxLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTokenContractTxLens, :focus, [%{
      contractaddress: @contract_address,
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
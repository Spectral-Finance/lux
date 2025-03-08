defmodule Lux.Integration.Etherscan.TxListInternalAddressLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TxListInternalAddress
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Address with internal transactions - using a more active address
  @address "0x7a250d5630b4cf539739df2c5dacb4c659f2488d" # Uniswap Router

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthTxListInternalAddressLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TxListInternalAddress",
      description: "Fetches internal transactions for a specific Ethereum address from Etherscan API",
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
      |> Map.put(:action, "txlistinternal")
    end
  end

  test "can fetch internal transactions for an address" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxListInternalAddress, :focus, [%{
               address: @address,
               chainid: 1
             }])

    # Verify we got results
    assert is_list(transactions)

    # If there are transactions, check their structure
    if length(transactions) > 0 do
      transaction = List.first(transactions)

      # Check that the transaction has the expected fields
      assert Map.has_key?(transaction, "blockNumber")
      assert Map.has_key?(transaction, "timeStamp")
      assert Map.has_key?(transaction, "from")
      assert Map.has_key?(transaction, "to")
      assert Map.has_key?(transaction, "value")
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")

      # Verify the address is involved in the transaction
      address_downcase = String.downcase(@address)
      assert String.downcase(transaction["from"]) == address_downcase ||
             String.downcase(transaction["to"]) == address_downcase
    end
  end

  test "can fetch internal transactions with pagination" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxListInternalAddress, :focus, [%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTxListInternalAddressLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTxListInternalAddressLens, :focus, [%{
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
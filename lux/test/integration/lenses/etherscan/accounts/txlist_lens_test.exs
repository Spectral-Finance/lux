defmodule Lux.Integration.Etherscan.TxListLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TxList
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Address with normal transactions (Vitalik's address)
  @address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthTxListLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Transaction List API",
      description: "Fetches normal transactions for an Ethereum address",
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
      |> Map.put(:action, "txlist")
    end
  end

  test "can fetch normal transactions for an address" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxList, :focus, [%{
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
      assert Map.has_key?(transaction, "hash")
      assert Map.has_key?(transaction, "from")
      assert Map.has_key?(transaction, "to")
      assert Map.has_key?(transaction, "value")
      assert Map.has_key?(transaction, "contractAddress")
      assert Map.has_key?(transaction, "input")
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")
      assert Map.has_key?(transaction, "gasPrice")
      assert Map.has_key?(transaction, "isError")
      assert Map.has_key?(transaction, "txreceipt_status")

      # Verify the address is involved in the transaction (case-insensitive comparison)
      address_downcase = String.downcase(@address)
      from_address = if transaction["from"], do: String.downcase(transaction["from"]), else: nil
      to_address = if transaction["to"], do: String.downcase(transaction["to"]), else: nil

      assert from_address == address_downcase || to_address == address_downcase
    end
  end

  test "can fetch transactions with pagination" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxList, :focus, [%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end

  test "can specify a block range for transactions" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxList, :focus, [%{
               address: @address,
               chainid: 1,
               startblock: 10000000,
               endblock: 15000000
             }])

    # Verify we got results
    assert is_list(transactions)

    # If there are transactions in this range, verify they're within the block range
    if length(transactions) > 0 do
      Enum.each(transactions, fn transaction ->
        block_number = String.to_integer(transaction["blockNumber"])
        assert block_number >= 10000000
        assert block_number <= 15000000
      end)
    end
  end

  test "can sort transactions in descending order" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxList, :focus, [%{
               address: @address,
               chainid: 1,
               sort: "desc"
             }])

    # Verify we got results
    assert is_list(transactions)

    # If there are at least 2 transactions, verify they're sorted in descending order
    if length(transactions) >= 2 do
      [first, second | _] = transactions

      first_block = String.to_integer(first["blockNumber"])
      second_block = String.to_integer(second["blockNumber"])

      assert first_block >= second_block
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthTxListLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTxListLens, :focus, [%{
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

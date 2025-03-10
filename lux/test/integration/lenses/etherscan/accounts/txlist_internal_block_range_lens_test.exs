defmodule Lux.Integration.Etherscan.TxListInternalBlockRangeLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.TxListInternalBlockRange
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Block range with internal transactions
  @startblock 13481773
  @endblock 13491773

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTxListInternalBlockRangeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan.TxListInternalBlockRange",
      description: "Fetches internal transactions within a specific block range from Etherscan API",
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

  test "can fetch internal transactions for a block range" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxListInternalBlockRange, :focus, [%{
               startblock: @startblock,
               endblock: @endblock,
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
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")

      # Verify the block number is within the range
      block_number = String.to_integer(transaction["blockNumber"])
      assert block_number >= @startblock && block_number <= @endblock
    end
  end

  test "can fetch internal transactions with pagination" do
    assert {:ok, %{result: transactions}} =
             RateLimitedAPI.call_standard(TxListInternalBlockRange, :focus, [%{
               startblock: @startblock,
               endblock: @endblock,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end

  test "fails when no auth is provided" do
    # The NoAuthTxListInternalBlockRangeLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTxListInternalBlockRangeLens, :focus, [%{
      startblock: @startblock,
      endblock: @endblock,
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
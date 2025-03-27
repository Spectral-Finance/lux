defmodule Lux.Integration.Etherscan.TxListInternalBlockRangeLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.TxListInternalBlockRange
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Block range with internal transactions
  @startblock 13_481_773
  @endblock 13_491_773

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch internal transactions for a block range" do
    assert {:ok, %{result: transactions}} =
             TxListInternalBlockRange.focus(%{
               startblock: @startblock,
               endblock: @endblock,
               chainid: 1
             })

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
             TxListInternalBlockRange.focus(%{
               startblock: @startblock,
               endblock: @endblock,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end
end 
defmodule Lux.Integration.Etherscan.TxListInternalTxhashLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.TxListInternalTxhash
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Transaction hash with internal transactions
  @txhash "0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch internal transactions for a transaction hash" do
    assert {:ok, %{result: transactions}} =
             TxListInternalTxhash.focus(%{
               txhash: @txhash,
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
      assert Map.has_key?(transaction, "from")
      assert Map.has_key?(transaction, "to")
      assert Map.has_key?(transaction, "value")
      assert Map.has_key?(transaction, "gas")
      assert Map.has_key?(transaction, "gasUsed")

      # Note: The API doesn't always return the hash field for internal transactions
      # when querying by txhash, so we don't check for it
    end
  end
end 
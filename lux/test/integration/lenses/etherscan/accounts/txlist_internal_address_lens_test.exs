defmodule Lux.Integration.Etherscan.TxListInternalAddressLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.TxListInternalAddress
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Address with internal transactions - using a more active address
  @address "0x7a250d5630b4cf539739df2c5dacb4c659f2488d" # Uniswap Router

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch internal transactions for an address" do
    assert {:ok, %{result: transactions}} =
             TxListInternalAddress.focus(%{
               address: @address,
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

      # Verify the address is involved in the transaction
      address_downcase = String.downcase(@address)
      assert String.downcase(transaction["from"]) == address_downcase ||
             String.downcase(transaction["to"]) == address_downcase
    end
  end

  test "can fetch internal transactions with pagination" do
    assert {:ok, %{result: transactions}} =
             TxListInternalAddress.focus(%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transactions) <= 5
  end
end 
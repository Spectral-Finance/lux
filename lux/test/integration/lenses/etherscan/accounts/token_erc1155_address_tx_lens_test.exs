defmodule Lux.Integration.Etherscan.TokenErc1155AddressTxLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.TokenErc1155AddressTx
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Address with ERC-1155 token transfers
  @address "0x83f564d180b58ad9a02a449105568189ee7de8cb"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch ERC-1155 transfers for an address" do
    assert {:ok, %{result: transfers}} =
             TokenErc1155AddressTx.focus(%{
               address: @address,
               chainid: 1
             })

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
             TokenErc1155AddressTx.focus(%{
               address: @address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end
end 
defmodule Lux.Integration.Etherscan.TokenContractTxLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.TokenContractTx
  import Lux.Integration.Etherscan.RateLimitedAPI

  # MKR token contract address
  @contract_address "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch ERC-20 transfers for a contract address" do
    assert {:ok, %{result: transfers}} =
             TokenContractTx.focus(%{
               contractaddress: @contract_address,
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
             TokenContractTx.focus(%{
               contractaddress: @contract_address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(transfers) <= 5
  end
end 
defmodule Lux.Integration.Etherscan.BeaconWithdrawalLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Etherscan.BeaconWithdrawal
  import Lux.Integration.Etherscan.RateLimitedAPI

  # Address with beacon withdrawals
  @withdrawal_address "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"

  # Add a delay between tests to avoid hitting the API rate limit
  setup :throttle_standard_api

  test "can fetch beacon withdrawals for an address" do
    assert {:ok, %{result: withdrawals}} =
             BeaconWithdrawal.focus(%{
               address: @withdrawal_address,
               chainid: 1
             })

    # Verify we got results
    assert is_list(withdrawals)

    # If there are withdrawals, check their structure
    if length(withdrawals) > 0 do
      withdrawal = List.first(withdrawals)

      # Check that the withdrawal has the expected fields
      assert Map.has_key?(withdrawal, "blockNumber")
      assert Map.has_key?(withdrawal, "timestamp")
      assert Map.has_key?(withdrawal, "withdrawalIndex")
      assert Map.has_key?(withdrawal, "validatorIndex")
      assert Map.has_key?(withdrawal, "address")
      assert Map.has_key?(withdrawal, "amount")

      # Verify the withdrawal address matches
      assert String.downcase(withdrawal["address"]) == String.downcase(@withdrawal_address)
    end
  end

  test "can fetch beacon withdrawals with pagination" do
    assert {:ok, %{result: withdrawals}} =
             BeaconWithdrawal.focus(%{
               address: @withdrawal_address,
               chainid: 1,
               page: 1,
               offset: 5
             })

    # Verify we got at most 5 results due to the offset parameter
    assert length(withdrawals) <= 5
  end

  test "can specify a block range for withdrawals" do
    assert {:ok, %{result: withdrawals}} =
             BeaconWithdrawal.focus(%{
               address: @withdrawal_address,
               chainid: 1,
               startblock: 17_000_000,
               endblock: 18_000_000
             })

    # Verify we got results
    assert is_list(withdrawals)

    # If there are withdrawals in this range, verify they're within the block range
    if length(withdrawals) > 0 do
      Enum.each(withdrawals, fn withdrawal ->
        block_number = String.to_integer(withdrawal["blockNumber"])
        assert block_number >= 17_000_000
        assert block_number <= 18_000_000
      end)
    end
  end
end

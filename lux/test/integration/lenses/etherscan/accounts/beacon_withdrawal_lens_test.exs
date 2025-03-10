defmodule Lux.Integration.Etherscan.BeaconWithdrawalLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.BeaconWithdrawal
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Address with beacon withdrawals
  @withdrawal_address "0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthBeaconWithdrawalLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Beacon Chain Withdrawals API",
      description: "Fetches beacon chain withdrawals for an Ethereum address",
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
      |> Map.put(:action, "withdrawals")
    end
  end

  test "can fetch beacon withdrawals for an address" do
    assert {:ok, %{result: withdrawals}} =
             RateLimitedAPI.call_standard(BeaconWithdrawal, :focus, [%{
               address: @withdrawal_address,
               chainid: 1
             }])

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
             RateLimitedAPI.call_standard(BeaconWithdrawal, :focus, [%{
               address: @withdrawal_address,
               chainid: 1,
               page: 1,
               offset: 5
             }])

    # Verify we got at most 5 results due to the offset parameter
    assert length(withdrawals) <= 5
  end

  test "can specify a block range for withdrawals" do
    assert {:ok, %{result: withdrawals}} =
             RateLimitedAPI.call_standard(BeaconWithdrawal, :focus, [%{
               address: @withdrawal_address,
               chainid: 1,
               startblock: 17000000,
               endblock: 18000000
             }])

    # Verify we got results
    assert is_list(withdrawals)

    # If there are withdrawals in this range, verify they're within the block range
    if length(withdrawals) > 0 do
      Enum.each(withdrawals, fn withdrawal ->
        block_number = String.to_integer(withdrawal["blockNumber"])
        assert block_number >= 17000000
        assert block_number <= 18000000
      end)
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthBeaconWithdrawalLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthBeaconWithdrawalLens, :focus, [%{
      address: @withdrawal_address,
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

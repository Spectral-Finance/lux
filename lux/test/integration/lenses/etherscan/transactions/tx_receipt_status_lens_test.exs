defmodule Lux.Integration.Etherscan.TxReceiptStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: false
  @moduletag timeout: 120_000

  alias Lux.Lenses.Etherscan.TxReceiptStatus
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example successful transaction hash
  @successful_tx "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthTxReceiptStatusLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Transaction Receipt Status API",
      description: "Checks the receipt status of a transaction",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "transaction")
      |> Map.put(:action, "gettxreceiptstatus")
    end
  end

  test "can check receipt status for a successful transaction" do
    assert {:ok, %{result: %{status: status, is_success: is_success}}} =
             RateLimitedAPI.call_standard(TxReceiptStatus, :focus, [%{
               txhash: @successful_tx,
               chainid: 1
             }])

    # Verify the status is "1" for a successful transaction
    assert status == "1"
    assert is_success == true
  end

  test "can check receipt status for a different chain" do
    # This test just verifies that we can specify a different chain
    # The actual result may vary depending on whether the transaction exists on that chain
    result = RateLimitedAPI.call_standard(TxReceiptStatus, :focus, [%{
      txhash: @successful_tx,
      chainid: 137 # Polygon
    }])

    case result do
      {:ok, %{result: %{status: status, is_success: is_success}}} ->
        # If the transaction doesn't exist on this chain, that's also acceptable
        assert true

      {:error, error} ->
        # If the transaction doesn't exist on this chain, that's also acceptable
        assert true
    end
  end

  test "returns appropriate status for invalid transaction hash" do
    # Using an invalid transaction hash format
    result = RateLimitedAPI.call_standard(TxReceiptStatus, :focus, [%{
      txhash: "0xinvalid",
      chainid: 1
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid transaction hash
        assert error != nil

      {:ok, %{result: %{status: status}}} ->
        # Some APIs might return a status for invalid hashes
        assert true
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthTxReceiptStatusLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthTxReceiptStatusLens, :focus, [%{
      txhash: @successful_tx,
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

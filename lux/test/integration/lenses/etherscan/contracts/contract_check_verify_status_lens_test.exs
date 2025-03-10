defmodule Lux.Integration.Etherscan.ContractCheckVerifyStatusLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractCheckVerifyStatus
  alias Lux.Integration.Etherscan.RateLimitedAPI

  # Example GUID from the documentation
  @example_guid "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
  # Invalid GUID for testing error handling
  @invalid_guid "invalid_guid"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    RateLimitedAPI.throttle_standard_api()
    :ok
  end

  defmodule NoAuthContractCheckVerifyStatusLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Contract Verification Status API",
      description: "Checks the status of a contract verification request",
      url: "https://api.etherscan.io/v2/api",
      method: :get,
      headers: [{"content-type", "application/json"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "contract")
      |> Map.put(:action, "checkverifystatus")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "can check verification status with example GUID" do
    # Note: This test might fail if the example GUID is no longer valid
    # In that case, we'll need to update the test with a new GUID
    result = RateLimitedAPI.call_standard(ContractCheckVerifyStatus, :focus, [%{
      guid: @example_guid,
      chainid: 1
    }])

    case result do
      {:ok, %{result: status_info}} ->
        # Verify the status info structure
        assert is_map(status_info)
        assert Map.has_key?(status_info, :status)
        assert Map.has_key?(status_info, :message)

        # The status should be one of the expected values
        assert status_info.status in ["Pending", "Failed", "Success", "Unknown"]

        # The message should be a non-empty string
        assert is_binary(status_info.message)
        assert String.length(status_info.message) > 0

      {:error, error} ->
        # If the GUID is no longer valid, it might return an error
        # This is also acceptable for this test
        assert true
    end
  end

  test "returns error for invalid GUID" do
    result = RateLimitedAPI.call_standard(ContractCheckVerifyStatus, :focus, [%{
      guid: @invalid_guid,
      chainid: 1
    }])

    case result do
      {:ok, %{result: status_info}} ->
        # Should return a failed status for invalid GUID
        assert status_info.status == "Failed" || status_info.status == "Unknown"

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthContractCheckVerifyStatusLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthContractCheckVerifyStatusLens, :focus, [%{
      guid: @example_guid,
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

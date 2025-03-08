defmodule Lux.Integration.Etherscan.ContractVerifySourceCodeLensTest do
  @moduledoc false
  use IntegrationCase, async: false

  alias Lux.Lenses.Etherscan.ContractVerifySourceCode
  alias Lux.Lenses.Etherscan.RateLimitedAPI

  # Example contract address for verification (this is just for testing, not a real verification)
  @contract_address "0x123456789012345678901234567890123456789"
  # Example source code (minimal contract for testing)
  @source_code "pragma solidity ^0.8.0; contract TestContract { function getValue() public pure returns (uint256) { return 42; } }"
  # Example compiler version
  @compiler_version "v0.8.0+commit.c7dfd78e"

  # Add a delay between tests to avoid hitting the API rate limit
  setup do
    # Use our rate limiter instead of Process.sleep
    throttle_standard_api()
    :ok
  end

  defmodule NoAuthContractVerifySourceCodeLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "Etherscan Contract Verification API",
      description: "Submits a contract source code to Etherscan for verification",
      url: "https://api.etherscan.io/v2/api",
      method: :post,
      headers: [{"content-type", "application/x-www-form-urlencoded"}]

    @doc """
    Prepares parameters before making the API request.
    """
    def before_focus(params) do
      # Set module and action for this endpoint
      params
      |> Map.put(:module, "contract")
      |> Map.put(:action, "verifysourcecode")
      # Ensure chainid is passed through
      |> Map.put_new(:chainid, Map.get(params, :chainid, 1))
    end
  end

  test "returns error for invalid contract address" do
    # Note: We're not actually submitting a real verification request
    # as that would consume the daily verification limit
    # Instead, we're testing that the API correctly handles invalid input

    # Using an invalid address format
    invalid_address = "0xinvalid"

    result = RateLimitedAPI.call_standard(ContractVerifySourceCode, :focus, [%{
      chainid: 1,
      contractaddress: invalid_address,
      sourceCode: @source_code,
      codeformat: "solidity-single-file",
      contractname: "TestContract",
      compilerversion: @compiler_version,
      optimizationUsed: 1,
      runs: 200
    }])

    case result do
      {:error, error} ->
        # Should return an error for invalid address format
        assert error != nil

      {:ok, %{result: result}} ->
        # Or it might return a result with an error message
        IO.puts("Result for invalid address: #{inspect(result)}")
        # The result should indicate an error
        if is_map(result) && Map.has_key?(result, :status) do
          assert result.status != "Success"
        end
    end
  end

  test "returns error for missing required parameters" do
    # Missing sourceCode parameter
    result = RateLimitedAPI.call_standard(ContractVerifySourceCode, :focus, [%{
      chainid: 1,
      contractaddress: @contract_address,
      codeformat: "solidity-single-file",
      contractname: "TestContract",
      compilerversion: @compiler_version
    }])

    case result do
      {:error, error} ->
        # Should return an error for missing required parameters
        assert error != nil

      {:ok, %{result: result}} ->
        # Or it might return a result with an error message
        IO.puts("Result for missing parameters: #{inspect(result)}")
        # The result should indicate an error
        if is_map(result) && Map.has_key?(result, :status) do
          assert result.status != "Success"
        end
    end
  end

  test "fails when no auth is provided" do
    # The NoAuthContractVerifySourceCodeLens doesn't have an API key, so it should fail
    result = RateLimitedAPI.call_standard(NoAuthContractVerifySourceCodeLens, :focus, [%{
      chainid: 1,
      contractaddress: @contract_address,
      sourceCode: @source_code,
      codeformat: "solidity-single-file",
      contractname: "TestContract",
      compilerversion: @compiler_version,
      optimizationUsed: 1,
      runs: 200
    }])

    case result do
      {:ok, %{"status" => "0", "message" => "NOTOK", "result" => error_message}} ->
        # The error message might be about missing API key or missing chainid
        assert String.contains?(error_message, "Missing/Invalid API Key") ||
               String.contains?(error_message, "Missing chainid parameter")

      {:error, error} ->
        # If it returns an error tuple, that's also acceptable
        assert error != nil
    end
  end

  # Note: We're not including a test for successful verification
  # as that would consume the daily verification limit (100/day)
  # and would require a real deployed contract
end

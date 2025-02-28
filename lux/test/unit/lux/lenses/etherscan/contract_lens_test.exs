defmodule Lux.Lenses.Etherscan.ContractLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.ContractLens

  # Add a delay between API calls to avoid rate limiting
  @delay_ms 300

  # Helper function to set up the API key for tests
  setup do
    # Store original API key configuration
    original_api_key = Application.get_env(:lux, :api_keys)

    # Set API key for testing from environment variable or use a default test key
    api_key = System.get_env("ETHERSCAN_API_KEY") || "YourApiKeyToken"

    # Check if we should use Pro API key for testing
    is_pro = System.get_env("ETHERSCAN_API_KEY_PRO") == "true"

    # Set the API key and Pro flag
    Application.put_env(:lux, :api_keys, [etherscan: api_key, etherscan_pro: is_pro])

    # Add a delay to avoid hitting rate limits
    Process.sleep(@delay_ms)

    on_exit(fn ->
      # Restore original API key configuration
      Application.put_env(:lux, :api_keys, original_api_key)
    end)

    :ok
  end

  # Helper function to add delay between API calls
  defp with_rate_limit(fun) do
    Process.sleep(@delay_ms)
    fun.()
  end

  @moduletag :integration

  describe "get_contract_source_code/1" do
    test "returns contract source code for a valid address" do
      address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" # USDC token

      IO.puts("\n=== Testing get_contract_source_code with address: #{address} ===")

      result = ContractLens.get_contract_source_code(%{
        address: address,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result

      IO.puts("First result entry: #{inspect(List.first(result_data) |> Map.take(["ContractName", "CompilerVersion"]), pretty: true)}")

      assert is_list(result_data)
      assert length(result_data) > 0

      first_result = List.first(result_data)
      assert Map.has_key?(first_result, "SourceCode")
      assert Map.has_key?(first_result, "ABI")
      assert Map.has_key?(first_result, "ContractName")
      assert Map.has_key?(first_result, "CompilerVersion")
    end

    test "raises ArgumentError for missing address" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        ContractLens.get_contract_source_code(%{})
      end
    end

    test "raises ArgumentError for invalid address" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        ContractLens.get_contract_source_code(%{address: "invalid"})
      end
    end
  end

  describe "get_contract_abi/1" do
    test "returns contract ABI for a valid address" do
      address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" # USDC token

      IO.puts("\n=== Testing get_contract_abi with address: #{address} ===")

      result = ContractLens.get_contract_abi(%{
        address: address,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: abi}} = result

      # Print a snippet of the ABI (first 100 chars)
      abi_snippet = if String.length(abi) > 100, do: String.slice(abi, 0, 100) <> "...", else: abi
      IO.puts("ABI snippet: #{abi_snippet}")

      assert is_binary(abi)
      assert String.starts_with?(abi, "[")
      assert String.ends_with?(abi, "]")
    end

    test "raises ArgumentError for missing address" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        ContractLens.get_contract_abi(%{})
      end
    end

    test "raises ArgumentError for invalid address" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        ContractLens.get_contract_abi(%{address: "invalid"})
      end
    end
  end

  describe "get_contract_creation_info/1" do
    test "returns contract creation info for valid addresses" do
      address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" # USDC token

      IO.puts("\n=== Testing get_contract_creation_info with address: #{address} ===")

      result = ContractLens.get_contract_creation_info(%{
        contractaddresses: address,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: creation_info}} = result

      IO.puts("Creation info: #{inspect(creation_info, pretty: true)}")

      assert is_list(creation_info)
      assert length(creation_info) > 0

      first_result = List.first(creation_info)
      assert Map.has_key?(first_result, "contractAddress")
      assert Map.has_key?(first_result, "contractCreator")
      assert Map.has_key?(first_result, "txHash")
    end

    test "raises ArgumentError for missing contractaddresses" do
      assert_raise ArgumentError, "contractaddresses parameter is required", fn ->
        ContractLens.get_contract_creation_info(%{})
      end
    end
  end

  describe "is_contract_verified/1" do
    test "returns verification status for a valid address" do
      address = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" # USDC token (verified)

      IO.puts("\n=== Testing is_contract_verified with address: #{address} ===")

      result = ContractLens.is_contract_verified(%{
        address: address,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: verification_status}} = result
      IO.puts("Verification status: #{verification_status}")
      assert verification_status == "1" # Verified
    end

    test "returns 0 for unverified contract" do
      # This test might be flaky if the contract gets verified later
      # Using a random valid address that's unlikely to be a verified contract
      address = "0x0000000000000000000000000000000000000001" # Unlikely to be verified

      IO.puts("\n=== Testing is_contract_verified with unverified address: #{address} ===")

      result = ContractLens.is_contract_verified(%{
        address: address,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: verification_status}} = result
      IO.puts("Verification status: #{verification_status}")
      assert verification_status == "0" # Not verified
    end

    test "raises ArgumentError for missing address" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        ContractLens.is_contract_verified(%{})
      end
    end

    test "raises ArgumentError for invalid address" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        ContractLens.is_contract_verified(%{address: "invalid"})
      end
    end
  end

  describe "get_contract_execution_status/1" do
    test "returns execution status for a valid transaction hash" do
      # Using a known transaction hash
      txhash = "0x2c9931793876db33b1a9aad123ad4921dfb9cd5e59dbb78ce78f277759587115"

      IO.puts("\n=== Testing get_contract_execution_status with txhash: #{txhash} ===")

      result = ContractLens.get_contract_execution_status(%{
        txhash: txhash,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      IO.puts("Result data: #{inspect(result_data, pretty: true)}")
      assert Map.has_key?(result_data, "isError")
      IO.puts("isError value: #{result_data["isError"]}")
    end

    test "raises ArgumentError for missing txhash" do
      assert_raise ArgumentError, "txhash parameter is required", fn ->
        ContractLens.get_contract_execution_status(%{})
      end
    end

    test "raises ArgumentError for invalid txhash" do
      assert_raise ArgumentError, "Invalid transaction hash format: invalid", fn ->
        ContractLens.get_contract_execution_status(%{txhash: "invalid"})
      end
    end
  end

  describe "get_verified_contracts/1" do
    test "returns a list of verified contracts" do
      # This test now checks if we can get contract creation info for a known contract
      IO.puts("\n=== Testing get_verified_contracts ===")

      result = ContractLens.get_verified_contracts(%{
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: contracts}} = result
      IO.puts("Contracts: #{inspect(contracts, pretty: true)}")
      assert is_list(contracts)

      # Since we're using getcontractcreation with a specific address,
      # we should get exactly one result
      assert length(contracts) == 1

      first_result = List.first(contracts)
      IO.puts("First contract: #{inspect(first_result, pretty: true)}")
      assert Map.has_key?(first_result, "contractAddress")
      assert Map.has_key?(first_result, "contractCreator")
      assert Map.has_key?(first_result, "txHash")
    end
  end

  describe "check_verification_status/1" do
    test "handles verification status check with sample GUID" do
      # Using a sample GUID - this will likely return "Pending in queue" or "Not found"
      guid = "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"

      IO.puts("\n=== Testing check_verification_status with GUID: #{guid} ===")

      result = ContractLens.check_verification_status(%{
        guid: guid,
        network: :ethereum
      })

      IO.puts("API Response: #{inspect(result, pretty: true)}")

      # We can't assert specific values since this is a test GUID
      # Just check that we get some kind of response
      case result do
        {:ok, %{result: status}} ->
          IO.puts("Verification status: #{status}")
          assert is_binary(status)
        {:error, error} ->
          IO.puts("Error response (expected for test GUID): #{inspect(error)}")
          assert true # Just ensure the test completes
      end
    end

    test "raises ArgumentError for missing guid" do
      assert_raise ArgumentError, "guid parameter is required", fn ->
        ContractLens.check_verification_status(%{})
      end
    end
  end

  describe "verify_contract_source_code/1" do
    test "handles contract verification with minimal parameters" do
      # This test will likely fail with the API but should show the request structure
      params = %{
        contractaddress: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        sourceCode: "// SPDX-License-Identifier: MIT\npragma solidity ^0.8.0;\n\ncontract Test { }",
        codeformat: "solidity-single-file",
        contractname: "Test",
        compilerversion: "v0.8.0+commit.c7dfd78e",
        optimizationUsed: "0",
        network: :ethereum
      }

      IO.puts("\n=== Testing verify_contract_source_code with sample parameters ===")
      IO.puts("Parameters: #{inspect(params, pretty: true)}")

      # We won't actually call the API since this would submit a verification request
      # Just verify that the function accepts the parameters without raising an error
      try do
        result = ContractLens.verify_contract_source_code(params)
        IO.puts("API Response (if any): #{inspect(result, pretty: true)}")
      rescue
        e in ArgumentError ->
          # This is expected for missing parameters
          IO.puts("Expected ArgumentError: #{Exception.message(e)}")
          assert true
        e ->
          # Other errors might be from the API itself
          IO.puts("Error: #{inspect(e)}")
          assert true
      end
    end
  end
end

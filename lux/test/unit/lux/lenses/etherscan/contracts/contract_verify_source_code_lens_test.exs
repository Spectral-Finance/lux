defmodule Lux.Lenses.Etherscan.ContractVerifySourceCodeLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractVerifySourceCode

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for single file verification" do
      # Set up the test parameters
      params = %{
        chainid: 1,
        contractaddress: "0x1234567890123456789012345678901234567890",
        sourceCode: "pragma solidity ^0.8.0; contract MyContract { }",
        codeformat: "solidity-single-file",
        contractname: "MyContract",
        compilerversion: "v0.8.0+commit.c7dfd78e",
        optimizationUsed: 1,
        runs: 200
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert conn.request_path == "/v2/api"

        # For POST requests, we can't easily check the form data in the test
        # So we'll just return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
        })
      end)

      # Call the lens
      result = ContractVerifySourceCode.focus(params)

      # Verify the result
      assert {:ok, %{result: verification_info}} = result
      assert verification_info.guid == "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
      assert verification_info.status == "Pending"
    end

    test "makes correct API call and processes the response for JSON input verification" do
      # Set up the test parameters
      params = %{
        chainid: 1,
        contractaddress: "0x1234567890123456789012345678901234567890",
        sourceCode: ~s({"language":"Solidity","sources":{"contracts/MyContract.sol":{"content":"pragma solidity ^0.8.0; contract MyContract { }"}},"settings":{"optimizer":{"enabled":true,"runs":200}}}),
        codeformat: "solidity-standard-json-input",
        contractname: "contracts/MyContract.sol:MyContract",
        compilerversion: "v0.8.0+commit.c7dfd78e"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "POST"
        assert conn.request_path == "/v2/api"

        # For POST requests, we can't easily check the form data in the test
        # So we'll just return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
        })
      end)

      # Call the lens
      result = ContractVerifySourceCode.focus(params)

      # Verify the result
      assert {:ok, %{result: verification_info}} = result
      assert verification_info.guid == "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
      assert verification_info.status == "Pending"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        chainid: 1,
        contractaddress: "0xinvalid",
        sourceCode: "pragma solidity ^0.8.0; contract MyContract { }",
        codeformat: "solidity-single-file",
        contractname: "MyContract",
        compilerversion: "v0.8.0+commit.c7dfd78e"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid address format"
        })
      end)

      # Call the lens
      result = ContractVerifySourceCode.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly and converts integer values to strings" do
      # Set up the test parameters
      params = %{
        chainid: 1,
        contractaddress: "0x1234567890123456789012345678901234567890",
        sourceCode: "pragma solidity ^0.8.0; contract MyContract { }",
        codeformat: "solidity-single-file",
        contractname: "MyContract",
        compilerversion: "v0.8.0+commit.c7dfd78e",
        optimizationUsed: 1,
        runs: 200,
        licenseType: 3
      }

      # Call the function
      result = ContractVerifySourceCode.before_focus(params)

      # Verify the result
      assert result.module == "contract"
      assert result.action == "verifysourcecode"
      assert result.contractaddress == "0x1234567890123456789012345678901234567890"
      assert result.sourceCode == "pragma solidity ^0.8.0; contract MyContract { }"
      assert result.codeformat == "solidity-single-file"
      assert result.contractname == "MyContract"
      assert result.compilerversion == "v0.8.0+commit.c7dfd78e"
      assert result.optimizationUsed == "1"
      assert result.runs == "200"
      assert result.licenseType == "3"
    end

    test "handles string values correctly" do
      # Set up the test parameters with string values
      params = %{
        chainid: 1,
        contractaddress: "0x1234567890123456789012345678901234567890",
        sourceCode: "pragma solidity ^0.8.0; contract MyContract { }",
        codeformat: "solidity-single-file",
        contractname: "MyContract",
        compilerversion: "v0.8.0+commit.c7dfd78e",
        optimizationUsed: "1",
        runs: "200",
        licenseType: "3"
      }

      # Call the function
      result = ContractVerifySourceCode.before_focus(params)

      # Verify the result
      assert result.optimizationUsed == "1"
      assert result.runs == "200"
      assert result.licenseType == "3"
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
      }

      # Call the function
      result = ContractVerifySourceCode.after_focus(response)

      # Verify the result
      assert {:ok, %{result: verification_info}} = result
      assert verification_info.guid == "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
      assert verification_info.status == "Pending"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = ContractVerifySourceCode.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

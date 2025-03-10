defmodule Lux.Lenses.Etherscan.ContractSourceCodeLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractSourceCode

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413",
        chainid: 1
      }

      # Sample ABI JSON string
      sample_abi_json = """
      [{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"}]
      """

      # Sample source code
      sample_source_code = """
      pragma solidity ^0.4.11;

      contract TheDAO {
          string public name = "The DAO";
          // More code here...
      }
      """

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "getsourcecode"
        assert query["address"] == "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "SourceCode" => sample_source_code,
              "ABI" => sample_abi_json,
              "ContractName" => "TheDAO",
              "CompilerVersion" => "v0.4.11+commit.68ef5810",
              "OptimizationUsed" => "1",
              "Runs" => "200",
              "ConstructorArguments" => "",
              "Library" => "",
              "LicenseType" => "MIT",
              "Proxy" => "0",
              "Implementation" => "",
              "SwarmSource" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = ContractSourceCode.focus(params)

      # Verify the result
      assert {:ok, %{result: contract_info}} = result
      assert contract_info.contract_name == "TheDAO"
      assert contract_info.source_code == sample_source_code
      assert is_list(contract_info.abi)
      assert length(contract_info.abi) == 1
      assert Enum.at(contract_info.abi, 0)["name"] == "name"
      assert contract_info.compiler_version == "v0.4.11+commit.68ef5810"
      assert contract_info.optimization_used == true
      assert contract_info.runs == "200"
      assert contract_info.license_type == "MIT"
      assert contract_info.proxy == false
    end

    test "handles non-JSON ABI response" do
      # Set up the test parameters
      params = %{
        address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413",
        chainid: 1
      }

      # Non-JSON ABI string
      non_json_abi = "Contract source code not verified"

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response with non-JSON ABI
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "SourceCode" => "",
              "ABI" => non_json_abi,
              "ContractName" => "",
              "CompilerVersion" => "",
              "OptimizationUsed" => "0",
              "Runs" => "",
              "ConstructorArguments" => "",
              "Library" => "",
              "LicenseType" => "",
              "Proxy" => "0",
              "Implementation" => "",
              "SwarmSource" => ""
            }
          ]
        })
      end)

      # Call the lens
      result = ContractSourceCode.focus(params)

      # Verify the result
      assert {:ok, %{result: contract_info}} = result
      assert contract_info.abi == non_json_abi
      assert contract_info.contract_name == ""
      assert contract_info.optimization_used == false
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        address: "0xinvalid",
        chainid: 1
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
      result = ContractSourceCode.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413",
        chainid: 1
      }

      # Call the function
      result = ContractSourceCode.before_focus(params)

      # Verify the result
      assert result.module == "contract"
      assert result.action == "getsourcecode"
      assert result.address == "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response with valid JSON ABI" do
      # Sample ABI JSON string
      sample_abi_json = """
      [{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"}]
      """

      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "SourceCode" => "contract Test {}",
            "ABI" => sample_abi_json,
            "ContractName" => "Test",
            "CompilerVersion" => "v0.8.0",
            "OptimizationUsed" => "1",
            "Runs" => "200",
            "ConstructorArguments" => "",
            "Library" => "",
            "LicenseType" => "MIT",
            "Proxy" => "0",
            "Implementation" => "",
            "SwarmSource" => ""
          }
        ]
      }

      # Call the function
      result = ContractSourceCode.after_focus(response)

      # Verify the result
      assert {:ok, %{result: contract_info}} = result
      assert contract_info.contract_name == "Test"
      assert contract_info.source_code == "contract Test {}"
      assert is_list(contract_info.abi)
      assert length(contract_info.abi) == 1
      assert Enum.at(contract_info.abi, 0)["name"] == "name"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = ContractSourceCode.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

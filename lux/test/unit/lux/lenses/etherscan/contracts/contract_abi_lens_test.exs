defmodule Lux.Lenses.Etherscan.ContractAbiLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractAbi

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
      [{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"success","type":"bool"}],"payable":false,"type":"function"}]
      """

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "getabi"
        assert query["address"] == "0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => sample_abi_json
        })
      end)

      # Call the lens
      result = ContractAbi.focus(params)

      # Verify the result
      assert {:ok, %{result: parsed_abi}} = result
      assert is_list(parsed_abi)
      assert length(parsed_abi) == 2
      assert Enum.at(parsed_abi, 0)["name"] == "name"
      assert Enum.at(parsed_abi, 1)["name"] == "approve"
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
          "result" => non_json_abi
        })
      end)

      # Call the lens
      result = ContractAbi.focus(params)

      # Verify the result
      assert {:ok, %{result: ^non_json_abi}} = result
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
      result = ContractAbi.focus(params)

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
      result = ContractAbi.before_focus(params)

      # Verify the result
      assert result.module == "contract"
      assert result.action == "getabi"
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
        "result" => sample_abi_json
      }

      # Call the function
      result = ContractAbi.after_focus(response)

      # Verify the result
      assert {:ok, %{result: parsed_abi}} = result
      assert is_list(parsed_abi)
      assert length(parsed_abi) == 1
      assert Enum.at(parsed_abi, 0)["name"] == "name"
    end

    test "processes successful response with non-JSON ABI" do
      # Non-JSON ABI string
      non_json_abi = "Contract source code not verified"

      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => non_json_abi
      }

      # Call the function
      result = ContractAbi.after_focus(response)

      # Verify the result
      assert {:ok, %{result: ^non_json_abi}} = result
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = ContractAbi.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

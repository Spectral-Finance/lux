defmodule Lux.Lenses.Etherscan.ContractCheckVerifyStatusLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.ContractCheckVerifyStatus

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for pending status" do
      # Set up the test parameters
      params = %{
        guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "contract"
        assert query["action"] == "checkverifystatus"
        assert query["guid"] == "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response for pending status
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "Pending in queue"
        })
      end)

      # Call the lens
      result = ContractCheckVerifyStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Pending"
      assert status_info.message == "Pending in queue"
    end

    test "makes correct API call and processes the response for success status" do
      # Set up the test parameters
      params = %{
        guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response for success status
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "Pass - Verified"
        })
      end)

      # Call the lens
      result = ContractCheckVerifyStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Success"
      assert status_info.message == "Pass - Verified"
    end

    test "makes correct API call and processes the response for failed status" do
      # Set up the test parameters
      params = %{
        guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response for failed status
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "Fail - Unable to verify"
        })
      end)

      # Call the lens
      result = ContractCheckVerifyStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Failed"
      assert status_info.message == "Fail - Unable to verify"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        guid: "invalid-guid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid GUID format"
        })
      end)

      # Call the lens
      result = ContractCheckVerifyStatus.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid GUID format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        guid: "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi",
        chainid: 1
      }

      # Call the function
      result = ContractCheckVerifyStatus.before_focus(params)

      # Verify the result
      assert result.module == "contract"
      assert result.action == "checkverifystatus"
      assert result.guid == "x3ryqcqr1zdknhfhkimqmizlcqpxncqc6nrvp3pgrcpfsqedqi"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes pending status response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "Pending in queue"
      }

      # Call the function
      result = ContractCheckVerifyStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Pending"
      assert status_info.message == "Pending in queue"
    end

    test "processes success status response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "Pass - Verified"
      }

      # Call the function
      result = ContractCheckVerifyStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Success"
      assert status_info.message == "Pass - Verified"
    end

    test "processes failed status response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "Fail - Unable to verify"
      }

      # Call the function
      result = ContractCheckVerifyStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Failed"
      assert status_info.message == "Fail - Unable to verify"
    end

    test "processes unknown status response" do
      # Create a mock response with an unknown status
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "Some unexpected status message"
      }

      # Call the function
      result = ContractCheckVerifyStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "Unknown"
      assert status_info.message == "Some unexpected status message"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid GUID format"
      }

      # Call the function
      result = ContractCheckVerifyStatus.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid GUID format"}} = result
    end
  end
end

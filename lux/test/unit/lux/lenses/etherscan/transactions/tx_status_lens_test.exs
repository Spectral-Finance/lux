defmodule Lux.Lenses.Etherscan.TxStatusLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxStatus

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for successful execution" do
      # Set up the test parameters
      params = %{
        txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "transaction"
        assert query["action"] == "getstatus"
        assert query["txhash"] == "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response for successful execution
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "isError" => "0",
            "errDescription" => ""
          }
        })
      end)

      # Call the lens
      result = TxStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "0"
      assert status_info.is_error == false
      assert status_info.error_message == ""
    end

    test "makes correct API call and processes the response for failed execution" do
      # Set up the test parameters
      params = %{
        txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response for failed execution
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "isError" => "1",
            "errDescription" => "Out of gas"
          }
        })
      end)

      # Call the lens
      result = TxStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "1"
      assert status_info.is_error == true
      assert status_info.error_message == "Out of gas"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        txhash: "0xinvalid",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid transaction hash format"
        })
      end)

      # Call the lens
      result = TxStatus.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid transaction hash format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        txhash: "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a",
        chainid: 1
      }

      # Call the function
      result = TxStatus.before_focus(params)

      # Verify the result
      assert result.module == "transaction"
      assert result.action == "getstatus"
      assert result.txhash == "0x15f8e5ea1079d9a0bb04a4c58ae5fe7654b5b2b4463375ff7ffb490aa0032f3a"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful execution response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "isError" => "0",
          "errDescription" => ""
        }
      }

      # Call the function
      result = TxStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "0"
      assert status_info.is_error == false
      assert status_info.error_message == ""
    end

    test "processes failed execution response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "isError" => "1",
          "errDescription" => "Out of gas"
        }
      }

      # Call the function
      result = TxStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "1"
      assert status_info.is_error == true
      assert status_info.error_message == "Out of gas"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid transaction hash format"
      }

      # Call the function
      result = TxStatus.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid transaction hash format"}} = result
    end
  end
end

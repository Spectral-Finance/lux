defmodule Lux.Lenses.Etherscan.TxReceiptStatusLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxReceiptStatus

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for successful transaction" do
      # Set up the test parameters
      params = %{
        txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76",
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
        assert query["action"] == "gettxreceiptstatus"
        assert query["txhash"] == "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response for successful transaction
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "status" => "1"
          }
        })
      end)

      # Call the lens
      result = TxReceiptStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "1"
      assert status_info.is_success == true
    end

    test "makes correct API call and processes the response for failed transaction" do
      # Set up the test parameters
      params = %{
        txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response for failed transaction
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "status" => "0"
          }
        })
      end)

      # Call the lens
      result = TxReceiptStatus.focus(params)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "0"
      assert status_info.is_success == false
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
      result = TxReceiptStatus.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid transaction hash format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        txhash: "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76",
        chainid: 1
      }

      # Call the function
      result = TxReceiptStatus.before_focus(params)

      # Verify the result
      assert result.module == "transaction"
      assert result.action == "gettxreceiptstatus"
      assert result.txhash == "0x513c1ba0bebf66436b5fed86ab668452b7805593c05073eb2d51d3a52f480a76"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful transaction response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "status" => "1"
        }
      }

      # Call the function
      result = TxReceiptStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "1"
      assert status_info.is_success == true
    end

    test "processes failed transaction response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "status" => "0"
        }
      }

      # Call the function
      result = TxReceiptStatus.after_focus(response)

      # Verify the result
      assert {:ok, %{result: status_info}} = result
      assert status_info.status == "0"
      assert status_info.is_success == false
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid transaction hash format"
      }

      # Call the function
      result = TxReceiptStatus.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid transaction hash format"}} = result
    end
  end
end

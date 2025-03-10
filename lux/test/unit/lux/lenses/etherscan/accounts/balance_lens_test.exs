defmodule Lux.Lenses.Etherscan.BalanceLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.Balance

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
        address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "balance"
        assert query["address"] == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        assert query["tag"] == "latest"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "123456789012345678"
        })
      end)

      # Call the lens
      result = Balance.focus(params)

      # Verify the result
      assert {:ok, %{result: "123456789012345678"}} = result
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        address: "0xinvalid",
        chainid: 1,
        tag: "latest"
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
      result = Balance.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        chainid: 1,
        tag: "latest"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a Pro API key error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "This endpoint requires a Pro subscription"
        })
      end)

      # Call the lens
      result = Balance.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        chainid: 1,
        tag: "latest"
      }

      # Call the function
      result = Balance.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "balance"
      assert result.address == "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
      assert result.chainid == 1
      assert result.tag == "latest"
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "123456789012345678"
      }

      # Call the function
      result = Balance.after_focus(response)

      # Verify the result
      assert {:ok, %{result: "123456789012345678"}} = result
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = Balance.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

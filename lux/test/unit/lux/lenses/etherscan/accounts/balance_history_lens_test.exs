defmodule Lux.Lenses.Etherscan.BalanceHistoryLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BalanceHistory

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: true  # Pro API key is required for this endpoint
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response" do
      # Set up the test parameters
      params = %{
        address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        blockno: 8_000_000,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "balancehistory"
        assert query["address"] == "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae"
        assert query["blockno"] == "8000000"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "123456789012345678"
        })
      end)

      # Call the lens
      result = BalanceHistory.focus(params)

      # Verify the result
      assert {:ok, %{result: "123456789012345678"}} = result
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        address: "0xinvalid",
        blockno: 8_000_000,
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
      result = BalanceHistory.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles Pro API key errors when Pro API key is not available" do
      # Temporarily set Pro API key to false
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        blockno: 8_000_000,
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        BalanceHistory.focus(params)
      end
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        blockno: 8_000_000,
        chainid: 1
      }

      # Call the function
      result = BalanceHistory.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "balancehistory"
      assert result.address == "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae"
      assert result.blockno == 8_000_000
      assert result.chainid == 1
    end

    test "raises error when Pro API key is not available" do
      # Temporarily set Pro API key to false
      Application.put_env(:lux, :api_keys, [
        etherscan: "TEST_API_KEY",
        etherscan_pro: false
      ])

      # Set up the test parameters
      params = %{
        address: "0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
        blockno: 8_000_000,
        chainid: 1
      }

      # Expect an error to be raised
      assert_raise ArgumentError, "This endpoint requires an Etherscan Pro API key.", fn ->
        BalanceHistory.before_focus(params)
      end
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
      result = BalanceHistory.after_focus(response)

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
      result = BalanceHistory.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

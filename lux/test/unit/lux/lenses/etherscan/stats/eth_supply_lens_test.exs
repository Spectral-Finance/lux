defmodule Lux.Lenses.Etherscan.EthSupplyLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.EthSupply

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
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "ethsupply"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "123456789012345678901234567"
        })
      end)

      # Call the lens
      result = EthSupply.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_supply, eth_supply: eth_supply}} = result
      assert eth_supply == 123_456_789_012_345_678_901_234_567
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "ethsupply"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "123456789012345678901234567"
        })
      end)

      # Call the lens
      result = EthSupply.focus(params)

      # Verify the result
      assert {:ok, %{result: eth_supply}} = result
      assert eth_supply == 123_456_789_012_345_678_901_234_567
    end

    test "handles error responses" do
      # Set up the test parameters
      params = %{
        chainid: 999_999 # Invalid chain ID
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid chain ID"
        })
      end)

      # Call the lens
      result = EthSupply.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        chainid: 1
      }

      # Call the function
      result = EthSupply.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethsupply"
      assert result.chainid == 1
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Call the function
      result = EthSupply.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "ethsupply"
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts to integer" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "123456789012345678901234567"
      }

      # Call the function
      result = EthSupply.after_focus(response)

      # Verify the result
      assert {:ok, %{result: eth_supply, eth_supply: eth_supply}} = result
      assert eth_supply == 123_456_789_012_345_678_901_234_567
    end

    test "processes non-numeric result" do
      # Create a mock response with non-numeric result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "unavailable"
      }

      # Call the function
      result = EthSupply.after_focus(response)

      # Verify the result
      assert {:ok, %{result: "unavailable", eth_supply: "unavailable"}} = result
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid chain ID"
      }

      # Call the function
      result = EthSupply.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end
end

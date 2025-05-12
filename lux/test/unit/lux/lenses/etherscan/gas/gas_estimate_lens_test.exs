defmodule Lux.Lenses.Etherscan.GasEstimateLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.GasEstimate

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
        gasprice: 2_000_000_000,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "gastracker"
        assert query["action"] == "gasestimate"
        assert query["gasprice"] == "2000000000"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "15"
        })
      end)

      # Call the lens
      result = GasEstimate.focus(params)

      # Verify the result
      assert {:ok, %{result: 15, estimated_seconds: 15}} = result
    end

    test "handles error responses" do
      # Set up the test parameters with invalid gas price
      params = %{
        gasprice: -1,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid gas price"
        })
      end)

      # Call the lens
      result = GasEstimate.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid gas price"}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        gasprice: 2_000_000_000,
        chainid: 1
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
      result = GasEstimate.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        gasprice: 2_000_000_000,
        chainid: 1
      }

      # Call the function
      result = GasEstimate.before_focus(params)

      # Verify the result
      assert result.module == "gastracker"
      assert result.action == "gasestimate"
      assert result.gasprice == 2_000_000_000
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts to integer" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "15"
      }

      # Call the function
      result = GasEstimate.after_focus(response)

      # Verify the result
      assert {:ok, %{result: 15, estimated_seconds: 15}} = result
    end

    test "processes non-numeric result" do
      # Create a mock response with non-numeric result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "unavailable"
      }

      # Call the function
      result = GasEstimate.after_focus(response)

      # Verify the result
      assert {:ok, %{result: "unavailable", estimated_seconds: "unavailable"}} = result
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid gas price"
      }

      # Call the function
      result = GasEstimate.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid gas price"}} = result
    end
  end
end

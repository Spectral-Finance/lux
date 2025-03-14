defmodule Lux.Lenses.Etherscan.BlockByTimestampLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BlockByTimestamp

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with default closest parameter" do
      # Set up the test parameters
      params = %{
        timestamp: 1_578_638_524,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "block"
        assert query["action"] == "getblocknobytime"
        assert query["timestamp"] == "1578638524"
        assert query["closest"] == "before"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "9251482"
        })
      end)

      # Call the lens
      result = BlockByTimestamp.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "9251482"
    end

    test "makes correct API call and processes the response with 'after' closest parameter" do
      # Set up the test parameters
      params = %{
        timestamp: 1_578_638_524,
        closest: "after",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["closest"] == "after"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "9251483"
        })
      end)

      # Call the lens
      result = BlockByTimestamp.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "9251483"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        timestamp: -1,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid timestamp"
        })
      end)

      # Call the lens
      result = BlockByTimestamp.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid timestamp"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with integer timestamp" do
      # Set up the test parameters with integer timestamp
      params = %{
        timestamp: 1_578_638_524,
        chainid: 1
      }

      # Call the function
      result = BlockByTimestamp.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblocknobytime"
      assert result.timestamp == "1578638524"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with string timestamp" do
      # Set up the test parameters with string timestamp
      params = %{
        timestamp: "1578638524",
        chainid: 1
      }

      # Call the function
      result = BlockByTimestamp.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblocknobytime"
      assert result.timestamp == "1578638524"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with closest parameter" do
      # Set up the test parameters with closest parameter
      params = %{
        timestamp: 1_578_638_524,
        closest: "after",
        chainid: 1
      }

      # Call the function
      result = BlockByTimestamp.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblocknobytime"
      assert result.timestamp == "1578638524"
      assert result.closest == "after"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "9251482"
      }

      # Call the function
      result = BlockByTimestamp.after_focus(response)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "9251482"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid timestamp"
      }

      # Call the function
      result = BlockByTimestamp.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid timestamp"}} = result
    end
  end
end

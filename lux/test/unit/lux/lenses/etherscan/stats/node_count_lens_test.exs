defmodule Lux.Lenses.Etherscan.NodeCountLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.NodeCount

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
        assert query["action"] == "nodecount"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "TotalNodeCount" => "1000",
            "EthNodeCount" => "800",
            "GethNodeCount" => "600",
            "ParityNodeCount" => "200",
            "OtherNodeCount" => "200"
          }
        })
      end)

      # Call the lens
      result = NodeCount.focus(params)

      # Verify the result
      assert {:ok, %{result: node_count, node_count: node_count}} = result
      assert node_count.total == 1000
      assert node_count.eth_nodes == 800
      assert node_count.geth_nodes == 600
      assert node_count.parity_nodes == 200
      assert node_count.other_nodes == 200
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "stats"
        assert query["action"] == "nodecount"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "TotalNodeCount" => "1000",
            "EthNodeCount" => "800",
            "GethNodeCount" => "600",
            "ParityNodeCount" => "200",
            "OtherNodeCount" => "200"
          }
        })
      end)

      # Call the lens
      result = NodeCount.focus(params)

      # Verify the result
      assert {:ok, %{result: node_count}} = result
      assert node_count.total == 1000
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
      result = NodeCount.focus(params)

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
      result = NodeCount.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "nodecount"
      assert result.chainid == 1
    end

    test "works with empty parameters" do
      # Set up empty parameters
      params = %{}

      # Call the function
      result = NodeCount.before_focus(params)

      # Verify the result
      assert result.module == "stats"
      assert result.action == "nodecount"
    end
  end

  describe "after_focus/1" do
    test "processes successful response and converts to integers" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "TotalNodeCount" => "1000",
          "EthNodeCount" => "800",
          "GethNodeCount" => "600",
          "ParityNodeCount" => "200",
          "OtherNodeCount" => "200"
        }
      }

      # Call the function
      result = NodeCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: node_count, node_count: node_count}} = result
      assert node_count.total == 1000
      assert node_count.eth_nodes == 800
      assert node_count.geth_nodes == 600
      assert node_count.parity_nodes == 200
      assert node_count.other_nodes == 200
    end

    test "processes non-numeric result" do
      # Create a mock response with non-numeric result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "TotalNodeCount" => "unavailable",
          "EthNodeCount" => "unavailable",
          "GethNodeCount" => "unavailable",
          "ParityNodeCount" => "unavailable",
          "OtherNodeCount" => "unavailable"
        }
      }

      # Call the function
      result = NodeCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: node_count}} = result
      assert node_count.total == "unavailable"
      assert node_count.eth_nodes == "unavailable"
      assert node_count.geth_nodes == "unavailable"
      assert node_count.parity_nodes == "unavailable"
      assert node_count.other_nodes == "unavailable"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid chain ID"
      }

      # Call the function
      result = NodeCount.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid chain ID"}} = result
    end
  end
end

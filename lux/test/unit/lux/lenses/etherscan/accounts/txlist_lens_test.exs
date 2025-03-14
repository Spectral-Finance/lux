defmodule Lux.Lenses.Etherscan.TxListLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.TxList

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
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        chainid: 1,
        startblock: 0,
        endblock: 99_999_999,
        page: 1,
        offset: 10,
        sort: "asc"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlist"
        assert query["address"] == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
        assert query["startblock"] == "0"
        assert query["endblock"] == "99999999"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["sort"] == "asc"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with sample transaction data
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "14422621",
              "timeStamp" => "1647362085",
              "hash" => "0x123abc...",
              "from" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
              "to" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "value" => "1000000000000000000",
              "gas" => "21000",
              "gasPrice" => "50000000000",
              "isError" => "0",
              "txreceipt_status" => "1"
            },
            %{
              "blockNumber" => "14422700",
              "timeStamp" => "1647363000",
              "hash" => "0x456def...",
              "from" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "to" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
              "value" => "500000000000000000",
              "gas" => "21000",
              "gasPrice" => "45000000000",
              "isError" => "0",
              "txreceipt_status" => "1"
            }
          ]
        })
      end)

      # Call the lens
      result = TxList.focus(params)

      # Verify the result
      assert {:ok, %{result: result_data}} = result
      assert is_list(result_data)
      assert length(result_data) == 2

      # Check first transaction data
      first_tx = Enum.at(result_data, 0)
      assert first_tx["blockNumber"] == "14422621"
      assert first_tx["from"] == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      assert first_tx["to"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert first_tx["value"] == "1000000000000000000"

      # Check second transaction data
      second_tx = Enum.at(result_data, 1)
      assert second_tx["blockNumber"] == "14422700"
      assert second_tx["from"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert second_tx["to"] == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      assert second_tx["value"] == "500000000000000000"
    end

    test "handles minimal parameters" do
      # Set up minimal test parameters (only required address)
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "txlist"
        assert query["address"] == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
        # Default values should be used for other parameters
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "14422621",
              "timeStamp" => "1647362085",
              "hash" => "0x123abc...",
              "from" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
              "to" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "value" => "1000000000000000000"
            }
          ]
        })
      end)

      # Call the lens
      result = TxList.focus(params)

      # Verify the result
      assert {:ok, %{result: result_data}} = result
      assert is_list(result_data)
      assert length(result_data) == 1
    end

    test "handles error responses" do
      # Set up the test parameters with an invalid address
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
      result = TxList.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end

    test "handles empty transaction list" do
      # Set up the test parameters
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty result list but with status 1 (success)
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => []
        })
      end)

      # Call the lens
      result = TxList.focus(params)

      # Verify the result
      assert {:ok, %{result: []}} = result
    end

    test "handles Pro API key errors" do
      # Set up the test parameters
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
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
      result = TxList.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "This endpoint requires an Etherscan Pro API key."}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
        chainid: 1,
        startblock: 0,
        endblock: 99_999_999,
        page: 1,
        offset: 10,
        sort: "asc"
      }

      # Call the function
      result = TxList.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "txlist"
      assert result.address == "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC"
      assert result.chainid == 1
      assert result.startblock == 0
      assert result.endblock == 99_999_999
      assert result.page == 1
      assert result.offset == 10
      assert result.sort == "asc"
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => [
          %{
            "blockNumber" => "14422621",
            "timeStamp" => "1647362085",
            "hash" => "0x123abc...",
            "from" => "0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC",
            "to" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
            "value" => "1000000000000000000"
          }
        ]
      }

      # Call the function
      result = TxList.after_focus(response)

      # Verify the result
      assert {:ok, %{result: result_data}} = result
      assert is_list(result_data)
      assert length(result_data) == 1
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = TxList.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

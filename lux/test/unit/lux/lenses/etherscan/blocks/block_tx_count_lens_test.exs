defmodule Lux.Lenses.Etherscan.BlockTxCountLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BlockTxCount

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with map result" do
      # Set up the test parameters
      params = %{
        blockno: 2_165_403,
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
        assert query["action"] == "getblocktxnscount"
        assert query["blockno"] == "2165403"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with map result
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "block" => 2_165_403,
            "txsCount" => 4,
            "internalTxsCount" => 0,
            "erc20TxsCount" => 0,
            "erc721TxsCount" => 0,
            "erc1155TxsCount" => 0
          }
        })
      end)

      # Call the lens
      result = BlockTxCount.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == 2_165_403
      assert block_info.transactions_count == 4
      assert block_info.internal_transactions_count == 0
      assert block_info.erc20_transactions_count == 0
      assert block_info.erc721_transactions_count == 0
      assert block_info.erc1155_transactions_count == 0
    end

    test "makes correct API call and processes the response with string result" do
      # Set up the test parameters
      params = %{
        blockno: 2_165_403,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response with string result (older API version)
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "73"
        })
      end)

      # Call the lens
      result = BlockTxCount.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.transactions_count == "73"
    end

    test "handles error responses" do
      # Set up the test parameters with invalid data
      params = %{
        blockno: -1,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an error response
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid block number"
        })
      end)

      # Call the lens
      result = BlockTxCount.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
    end

    test "raises error for unsupported chain ID" do
      # Set up the test parameters with unsupported chain ID
      params = %{
        blockno: 2_165_403,
        chainid: 137
      }

      # Verify that it raises an error
      assert_raise RuntimeError, "This endpoint is only available on Etherscan (chainId 1)", fn ->
        BlockTxCount.focus(params)
      end
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with integer block number" do
      # Set up the test parameters with integer block number
      params = %{
        blockno: 2_165_403,
        chainid: 1
      }

      # Call the function
      result = BlockTxCount.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblocktxnscount"
      assert result.blockno == "2165403"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with string block number" do
      # Set up the test parameters with string block number
      params = %{
        blockno: "2165403",
        chainid: 1
      }

      # Call the function
      result = BlockTxCount.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblocktxnscount"
      assert result.blockno == "2165403"
      assert result.chainid == 1
    end

    test "raises error for unsupported chain ID" do
      # Set up the test parameters with unsupported chain ID
      params = %{
        blockno: 2_165_403,
        chainid: 137
      }

      # Verify that it raises an error
      assert_raise RuntimeError, "This endpoint is only available on Etherscan (chainId 1)", fn ->
        BlockTxCount.before_focus(params)
      end
    end
  end

  describe "after_focus/1" do
    test "processes successful response with map result" do
      # Create a mock response with map result
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "block" => 2_165_403,
          "txsCount" => 4,
          "internalTxsCount" => 0,
          "erc20TxsCount" => 0,
          "erc721TxsCount" => 0,
          "erc1155TxsCount" => 0
        }
      }

      # Call the function
      result = BlockTxCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == 2_165_403
      assert block_info.transactions_count == 4
      assert block_info.internal_transactions_count == 0
      assert block_info.erc20_transactions_count == 0
      assert block_info.erc721_transactions_count == 0
      assert block_info.erc1155_transactions_count == 0
    end

    test "processes successful response with string result" do
      # Create a mock response with string result (older API version)
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => "73"
      }

      # Call the function
      result = BlockTxCount.after_focus(response)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.transactions_count == "73"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid block number"
      }

      # Call the function
      result = BlockTxCount.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
    end
  end
end

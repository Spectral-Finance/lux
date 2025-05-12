defmodule Lux.Lenses.Etherscan.MinedBlocksLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.MinedBlocks

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for canonical blocks" do
      # Set up the test parameters
      params = %{
        address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
        chainid: 1,
        blocktype: "blocks",
        page: 1,
        offset: 10
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "getminedblocks"
        assert query["address"] == "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b"
        assert query["blocktype"] == "blocks"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "blockReward" => "2000000000000000000"
            },
            %{
              "blockNumber" => "12345679",
              "timeStamp" => "1622222230",
              "blockReward" => "2000000000000000000"
            }
          ]
        })
      end)

      # Call the lens
      result = MinedBlocks.focus(params)

      # Verify the result
      assert {:ok, %{result: blocks}} = result
      assert length(blocks) == 2
      assert Enum.at(blocks, 0)["blockNumber"] == "12345678"
      assert Enum.at(blocks, 1)["blockNumber"] == "12345679"
    end

    test "makes correct API call and processes the response for uncle blocks" do
      # Set up the test parameters
      params = %{
        address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
        chainid: 1,
        blocktype: "uncles",
        page: 1,
        offset: 10
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Verify the request
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["module"] == "account"
        assert query["action"] == "getminedblocks"
        assert query["address"] == "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b"
        assert query["blocktype"] == "uncles"
        assert query["page"] == "1"
        assert query["offset"] == "10"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "blockNumber" => "12345678",
              "timeStamp" => "1622222222",
              "blockReward" => "1500000000000000000"
            }
          ]
        })
      end)

      # Call the lens
      result = MinedBlocks.focus(params)

      # Verify the result
      assert {:ok, %{result: blocks}} = result
      assert length(blocks) == 1
      assert Enum.at(blocks, 0)["blockNumber"] == "12345678"
      assert Enum.at(blocks, 0)["blockReward"] == "1500000000000000000"
    end

    test "handles empty blocks list" do
      # Set up the test parameters
      params = %{
        address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return an empty blocks list
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No blocks found"
        })
      end)

      # Call the lens
      result = MinedBlocks.focus(params)

      # Verify the result
      assert {:error, %{message: "No transactions found", result: "No blocks found"}} = result
    end

    test "handles error responses" do
      # Set up the test parameters
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
      result = MinedBlocks.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly" do
      # Set up the test parameters
      params = %{
        address: "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b",
        chainid: 1,
        blocktype: "blocks",
        page: 1,
        offset: 10
      }

      # Call the function
      result = MinedBlocks.before_focus(params)

      # Verify the result
      assert result.module == "account"
      assert result.action == "getminedblocks"
      assert result.address == "0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b"
      assert result.chainid == 1
      assert result.blocktype == "blocks"
      assert result.page == 1
      assert result.offset == 10
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
            "blockNumber" => "12345678",
            "timeStamp" => "1622222222",
            "blockReward" => "2000000000000000000"
          }
        ]
      }

      # Call the function
      result = MinedBlocks.after_focus(response)

      # Verify the result
      assert {:ok, %{result: [block]}} = result
      assert block["blockNumber"] == "12345678"
      assert block["blockReward"] == "2000000000000000000"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid address format"
      }

      # Call the function
      result = MinedBlocks.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid address format"}} = result
    end
  end
end

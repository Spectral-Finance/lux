defmodule Lux.Lenses.Etherscan.BlockRewardLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BlockReward

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response with block rewards" do
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
        assert query["action"] == "getblockreward"
        assert query["blockno"] == "2165403"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response with block rewards
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "blockNumber" => "2165403",
            "timeStamp" => "1472533979",
            "blockMiner" => "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3",
            "blockReward" => "5314181600000000000",
            "uncles" => [
              %{
                "miner" => "0xb3b7874f13387d44a3398d298b075b7a3505d8d4",
                "unclePosition" => "0",
                "blockreward" => "3750000000000000000"
              }
            ]
          }
        })
      end)

      # Call the lens
      result = BlockReward.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "2165403"
      assert block_info.timestamp == "1472533979"
      assert block_info.block_miner == "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3"
      assert block_info.block_reward == "5314181600000000000"
      assert length(block_info.uncles) == 1

      # Verify uncle information
      [uncle] = block_info.uncles
      assert uncle.miner == "0xb3b7874f13387d44a3398d298b075b7a3505d8d4"
      assert uncle.uncle_position == "0"
      assert uncle.block_reward == "3750000000000000000"
    end

    test "makes correct API call and processes the response with no uncles" do
      # Set up the test parameters
      params = %{
        blockno: 2_165_403,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response with no uncles
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "blockNumber" => "2165403",
            "timeStamp" => "1472533979",
            "blockMiner" => "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3",
            "blockReward" => "5000000000000000000",
            "uncles" => []
          }
        })
      end)

      # Call the lens
      result = BlockReward.focus(params)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "2165403"
      assert block_info.timestamp == "1472533979"
      assert block_info.block_miner == "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3"
      assert block_info.block_reward == "5000000000000000000"
      assert block_info.uncles == []
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
      result = BlockReward.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
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
      result = BlockReward.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblockreward"
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
      result = BlockReward.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblockreward"
      assert result.blockno == "2165403"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response with uncles" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "blockNumber" => "2165403",
          "timeStamp" => "1472533979",
          "blockMiner" => "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3",
          "blockReward" => "5314181600000000000",
          "uncles" => [
            %{
              "miner" => "0xb3b7874f13387d44a3398d298b075b7a3505d8d4",
              "unclePosition" => "0",
              "blockreward" => "3750000000000000000"
            }
          ]
        }
      }

      # Call the function
      result = BlockReward.after_focus(response)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "2165403"
      assert block_info.timestamp == "1472533979"
      assert block_info.block_miner == "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3"
      assert block_info.block_reward == "5314181600000000000"
      assert length(block_info.uncles) == 1

      # Verify uncle information
      [uncle] = block_info.uncles
      assert uncle.miner == "0xb3b7874f13387d44a3398d298b075b7a3505d8d4"
      assert uncle.uncle_position == "0"
      assert uncle.block_reward == "3750000000000000000"
    end

    test "processes successful response with no uncles" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "blockNumber" => "2165403",
          "timeStamp" => "1472533979",
          "blockMiner" => "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3",
          "blockReward" => "5000000000000000000",
          "uncles" => []
        }
      }

      # Call the function
      result = BlockReward.after_focus(response)

      # Verify the result
      assert {:ok, %{result: block_info}} = result
      assert block_info.block_number == "2165403"
      assert block_info.timestamp == "1472533979"
      assert block_info.block_miner == "0x13a06d3dfe21e0db5c016c03ea7d2509f7f8d1e3"
      assert block_info.block_reward == "5000000000000000000"
      assert block_info.uncles == []
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid block number"
      }

      # Call the function
      result = BlockReward.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
    end
  end
end

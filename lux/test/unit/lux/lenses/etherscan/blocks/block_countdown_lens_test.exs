defmodule Lux.Lenses.Etherscan.BlockCountdownLensTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.BlockCountdown

  setup do
    # Set up test API key in the configuration
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])



    :ok
  end

  describe "focus/1" do
    test "makes correct API call and processes the response for future block" do
      # Set up the test parameters
      params = %{
        blockno: 16_701_588,
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
        assert query["action"] == "getblockcountdown"
        assert query["blockno"] == "16701588"
        assert query["apikey"] == "TEST_API_KEY"

        # Return a mock response for a future block
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "CurrentBlock" => "16700000",
            "CountdownBlock" => "16701588",
            "RemainingBlock" => "1588",
            "EstimateTimeInSec" => "19056"
          }
        })
      end)

      # Call the lens
      result = BlockCountdown.focus(params)

      # Verify the result
      assert {:ok, %{result: countdown_info}} = result
      assert countdown_info.current_block == "16700000"
      assert countdown_info.countdown_block == "16701588"
      assert countdown_info.remaining_blocks == "1588"
      assert countdown_info.estimated_time_in_sec == "19056"
    end

    test "makes correct API call and processes the response for past block" do
      # Set up the test parameters
      params = %{
        blockno: 16_000_000,
        chainid: 1
      }

      # Mock the API response
      Req.Test.expect(Lux.Lens, fn conn ->
        # Return a mock response for a past block
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "CurrentBlock" => "16700000",
            "CountdownBlock" => "16000000",
            "RemainingBlock" => "0",
            "EstimateTimeInSec" => "0"
          }
        })
      end)

      # Call the lens
      result = BlockCountdown.focus(params)

      # Verify the result
      assert {:ok, %{result: countdown_info}} = result
      assert countdown_info.current_block == "16700000"
      assert countdown_info.countdown_block == "16000000"
      assert countdown_info.remaining_blocks == "0"
      assert countdown_info.estimated_time_in_sec == "0"
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
      result = BlockCountdown.focus(params)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
    end
  end

  describe "before_focus/1" do
    test "prepares parameters correctly with integer block number" do
      # Set up the test parameters with integer block number
      params = %{
        blockno: 16_701_588,
        chainid: 1
      }

      # Call the function
      result = BlockCountdown.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblockcountdown"
      assert result.blockno == "16701588"
      assert result.chainid == 1
    end

    test "prepares parameters correctly with string block number" do
      # Set up the test parameters with string block number
      params = %{
        blockno: "16701588",
        chainid: 1
      }

      # Call the function
      result = BlockCountdown.before_focus(params)

      # Verify the result
      assert result.module == "block"
      assert result.action == "getblockcountdown"
      assert result.blockno == "16701588"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response for future block" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "CurrentBlock" => "16700000",
          "CountdownBlock" => "16701588",
          "RemainingBlock" => "1588",
          "EstimateTimeInSec" => "19056"
        }
      }

      # Call the function
      result = BlockCountdown.after_focus(response)

      # Verify the result
      assert {:ok, %{result: countdown_info}} = result
      assert countdown_info.current_block == "16700000"
      assert countdown_info.countdown_block == "16701588"
      assert countdown_info.remaining_blocks == "1588"
      assert countdown_info.estimated_time_in_sec == "19056"
    end

    test "processes successful response for past block" do
      # Create a mock response
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "CurrentBlock" => "16700000",
          "CountdownBlock" => "16000000",
          "RemainingBlock" => "0",
          "EstimateTimeInSec" => "0"
        }
      }

      # Call the function
      result = BlockCountdown.after_focus(response)

      # Verify the result
      assert {:ok, %{result: countdown_info}} = result
      assert countdown_info.current_block == "16700000"
      assert countdown_info.countdown_block == "16000000"
      assert countdown_info.remaining_blocks == "0"
      assert countdown_info.estimated_time_in_sec == "0"
    end

    test "processes error response" do
      # Create a mock error response
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Invalid block number"
      }

      # Call the function
      result = BlockCountdown.after_focus(response)

      # Verify the result
      assert {:error, %{message: "Error", result: "Invalid block number"}} = result
    end
  end
end

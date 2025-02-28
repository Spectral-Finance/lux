defmodule Lux.Lenses.Etherscan.BlockLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.BlockLens

  # Add a delay between API calls to avoid rate limiting
  @delay_ms 300

  # Helper function to set up the API key for tests
  setup do
    # Store original API key configuration
    original_api_key = Application.get_env(:lux, :api_keys)

    # Set API key for testing from environment variable or use a default test key
    api_key = System.get_env("ETHERSCAN_API_KEY") || "YourApiKeyToken"

    # Check if we should use Pro API key for testing
    is_pro = System.get_env("ETHERSCAN_API_KEY_PRO") == "true"

    # Set the API key and Pro flag
    Application.put_env(:lux, :api_keys, [etherscan: api_key, etherscan_pro: is_pro])

    # Add a delay to avoid hitting rate limits
    Process.sleep(@delay_ms)

    on_exit(fn ->
      # Restore original API key configuration
      Application.put_env(:lux, :api_keys, original_api_key)
    end)

    :ok
  end

  # Helper function to add delay between API calls
  defp with_rate_limit(fun) do
    Process.sleep(@delay_ms)
    fun.()
  end

  # Helper function to check if a result is either successful or a Pro API error
  defp assert_success_or_pro_error(result) do
    case result do
      {:ok, %{result: _}} ->
        assert true
      {:error, %{message: "NOTOK", result: error_message}} ->
        assert error_message =~ "API Pro" or error_message =~ "Pro API"
      other ->
        flunk("Expected either a successful result or a Pro API error, got: #{inspect(other)}")
    end
  end

  describe "get_block_reward/1" do
    @tag :integration
    test "fetches block reward for a valid block number" do
      # Using the example block number from the documentation
      blockno = 2165403

      result = with_rate_limit(fn -> BlockLens.get_block_reward(%{blockno: blockno}) end)

      IO.puts("\n=== Block Reward Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      assert is_map(result_data)
      assert Map.has_key?(result_data, "blockNumber")
      assert Map.has_key?(result_data, "blockReward")
      assert Map.has_key?(result_data, "uncleInclusionReward")
    end

    test "raises error when blockno is missing" do
      assert_raise ArgumentError, "blockno parameter is required", fn ->
        BlockLens.get_block_reward(%{})
      end
    end

    test "raises error when blockno is invalid" do
      assert_raise ArgumentError, ~r/blockno must be an integer/, fn ->
        BlockLens.get_block_reward(%{blockno: "invalid"})
      end
    end
  end

  describe "get_block_txns_count/1" do
    @tag :integration
    test "fetches block transactions count for a valid block number" do
      # Using the example block number from the documentation
      blockno = 2165403

      result = with_rate_limit(fn -> BlockLens.get_block_txns_count(%{blockno: blockno}) end)

      IO.puts("\n=== Block Transactions Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      # The API response format has changed - it now returns a map with transaction counts
      assert is_map(result_data)
      assert Map.has_key?(result_data, "txsCount")
      # The transaction count should be a number
      assert is_integer(result_data["txsCount"])
    end

    test "raises error when blockno is missing" do
      assert_raise ArgumentError, "blockno parameter is required", fn ->
        BlockLens.get_block_txns_count(%{})
      end
    end

    test "raises error when blockno is invalid" do
      assert_raise ArgumentError, ~r/blockno must be an integer/, fn ->
        BlockLens.get_block_txns_count(%{blockno: "invalid"})
      end
    end
  end

  describe "get_block_countdown/1" do
    @tag :integration
    test "fetches block countdown for a future block number" do
      # Using a block number that is likely in the future
      future_block = 22042642

      result = with_rate_limit(fn -> BlockLens.get_block_countdown(%{blockno: future_block}) end)

      IO.puts("\n=== Block Countdown Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # The result could be either a countdown or an error if the block is too far in the future
      case result do
        {:ok, %{result: result_data}} ->
          assert is_map(result_data)
          assert Map.has_key?(result_data, "CurrentBlock")
          assert Map.has_key?(result_data, "CountdownBlock")
          assert Map.has_key?(result_data, "RemainingBlock")
          assert Map.has_key?(result_data, "EstimateTimeInSec")
        {:error, _} ->
          # This is also acceptable if the block is too far in the future
          assert true
      end
    end

    test "raises error when blockno is missing" do
      assert_raise ArgumentError, "blockno parameter is required", fn ->
        BlockLens.get_block_countdown(%{})
      end
    end

    test "raises error when blockno is invalid" do
      assert_raise ArgumentError, ~r/blockno must be an integer/, fn ->
        BlockLens.get_block_countdown(%{blockno: "invalid"})
      end
    end
  end

  describe "get_block_no_by_time/1" do
    @tag :integration
    test "fetches block number by timestamp" do
      # Using the example timestamp from the documentation
      timestamp = 1578638524
      closest = "before"

      result = with_rate_limit(fn -> BlockLens.get_block_no_by_time(%{timestamp: timestamp, closest: closest}) end)

      IO.puts("\n=== Block Number by Timestamp Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: result_data}} = result
      # The result should be a string containing the block number
      assert is_binary(result_data)
      # The block number should be a number
      {block_number, _} = Integer.parse(result_data)
      assert is_integer(block_number)
    end

    test "raises error when timestamp is missing" do
      assert_raise ArgumentError, "timestamp parameter is required", fn ->
        BlockLens.get_block_no_by_time(%{})
      end
    end

    test "raises error when timestamp is invalid" do
      assert_raise ArgumentError, ~r/timestamp must be an integer/, fn ->
        BlockLens.get_block_no_by_time(%{timestamp: "invalid"})
      end
    end
  end

  describe "get_daily_avg_block_size/1" do
    @tag :integration
    test "fetches daily average block size with Pro API key" do
      # Using the example dates from the documentation
      startdate = "2019-02-01"
      enddate = "2019-02-28"
      sort = "asc"

      result = with_rate_limit(fn ->
        BlockLens.get_daily_avg_block_size(%{startdate: startdate, enddate: enddate, sort: sort})
      end)

      IO.puts("\n=== Daily Average Block Size Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key
      assert_success_or_pro_error(result)
    end

    test "raises error when startdate is missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        BlockLens.get_daily_avg_block_size(%{enddate: "2019-02-28"})
      end
    end

    test "raises error when enddate is missing" do
      assert_raise ArgumentError, "enddate parameter is required", fn ->
        BlockLens.get_daily_avg_block_size(%{startdate: "2019-02-01"})
      end
    end

    test "raises error when date format is invalid" do
      assert_raise ArgumentError, ~r/startdate must be in yyyy-MM-dd format/, fn ->
        BlockLens.get_daily_avg_block_size(%{startdate: "01-02-2019", enddate: "2019-02-28"})
      end
    end
  end

  describe "get_daily_block_count/1" do
    @tag :integration
    test "fetches daily block count with Pro API key" do
      # Using the example dates from the documentation
      startdate = "2019-02-01"
      enddate = "2019-02-28"
      sort = "asc"

      result = with_rate_limit(fn ->
        BlockLens.get_daily_block_count(%{startdate: startdate, enddate: enddate, sort: sort})
      end)

      IO.puts("\n=== Daily Block Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key
      assert_success_or_pro_error(result)
    end

    test "raises error when startdate is missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        BlockLens.get_daily_block_count(%{enddate: "2019-02-28"})
      end
    end
  end

  describe "get_daily_block_rewards/1" do
    @tag :integration
    test "fetches daily block rewards with Pro API key" do
      # Using the example dates from the documentation
      startdate = "2019-02-01"
      enddate = "2019-02-28"
      sort = "asc"

      result = with_rate_limit(fn ->
        BlockLens.get_daily_block_rewards(%{startdate: startdate, enddate: enddate, sort: sort})
      end)

      IO.puts("\n=== Daily Block Rewards Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key
      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_avg_block_time/1" do
    @tag :integration
    test "fetches daily average block time with Pro API key" do
      # Using the example dates from the documentation
      startdate = "2019-02-01"
      enddate = "2019-02-28"
      sort = "asc"

      result = with_rate_limit(fn ->
        BlockLens.get_daily_avg_block_time(%{startdate: startdate, enddate: enddate, sort: sort})
      end)

      IO.puts("\n=== Daily Average Block Time Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key
      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_uncle_block_count/1" do
    @tag :integration
    test "fetches daily uncle block count with Pro API key" do
      # Using the example dates from the documentation
      startdate = "2019-02-01"
      enddate = "2019-02-28"
      sort = "asc"

      result = with_rate_limit(fn ->
        BlockLens.get_daily_uncle_block_count(%{startdate: startdate, enddate: enddate, sort: sort})
      end)

      IO.puts("\n=== Daily Uncle Block Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key
      assert_success_or_pro_error(result)
    end
  end
end

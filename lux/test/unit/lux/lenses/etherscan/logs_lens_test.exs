defmodule Lux.Lenses.Etherscan.LogsLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.LogsLens

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

  describe "get_logs_by_address/1" do
    @tag :integration
    test "fetches event logs for a valid address and block range" do
      # Using the example from the documentation
      address = "0xbd3531da5cf5857e7cfaa92426877b022e612cf8"
      from_block = 12878196
      to_block = 12878196

      result = with_rate_limit(fn ->
        LogsLens.get_logs_by_address(%{
          address: address,
          fromBlock: from_block,
          toBlock: to_block
        })
      end)

      IO.puts("\n=== Event Logs by Address Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: logs}} = result
      assert is_list(logs)

      # If logs are returned, check their structure
      if length(logs) > 0 do
        first_log = List.first(logs)
        assert is_map(first_log)
        assert Map.has_key?(first_log, "address")
        assert Map.has_key?(first_log, "topics")
        assert Map.has_key?(first_log, "data")
        assert Map.has_key?(first_log, "blockNumber")
        assert Map.has_key?(first_log, "timeStamp")
        assert Map.has_key?(first_log, "gasPrice")
        assert Map.has_key?(first_log, "gasUsed")
        assert Map.has_key?(first_log, "logIndex")
        assert Map.has_key?(first_log, "transactionHash")
        assert Map.has_key?(first_log, "transactionIndex")
      end
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        LogsLens.get_logs_by_address(%{})
      end
    end

    test "raises error when address is invalid" do
      assert_raise ArgumentError, "Invalid Ethereum address format: invalid", fn ->
        LogsLens.get_logs_by_address(%{address: "invalid"})
      end
    end

    test "raises error when block number is invalid" do
      assert_raise ArgumentError, ~r/fromBlock must be a valid integer block number/, fn ->
        LogsLens.get_logs_by_address(%{
          address: "0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
          fromBlock: "invalid"
        })
      end
    end
  end

  describe "get_logs_by_topics/1" do
    @tag :integration
    test "fetches event logs filtered by topics" do
      # Using the example from the documentation
      from_block = 12878196
      to_block = 12879196
      topic0 = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
      topic1 = "0x0000000000000000000000000000000000000000000000000000000000000000"
      topic0_1_opr = "and"

      result = with_rate_limit(fn ->
        LogsLens.get_logs_by_topics(%{
          fromBlock: from_block,
          toBlock: to_block,
          topic0: topic0,
          topic1: topic1,
          topic0_1_opr: topic0_1_opr
        })
      end)

      IO.puts("\n=== Event Logs by Topics Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: logs}} = result
      assert is_list(logs)

      # If logs are returned, check their structure
      if length(logs) > 0 do
        first_log = List.first(logs)
        assert is_map(first_log)
        assert Map.has_key?(first_log, "address")
        assert Map.has_key?(first_log, "topics")
        assert Map.has_key?(first_log, "data")
        assert Map.has_key?(first_log, "blockNumber")
      end
    end

    test "raises error when fromBlock is missing" do
      assert_raise ArgumentError, "fromBlock parameter is required", fn ->
        LogsLens.get_logs_by_topics(%{
          toBlock: 12879196,
          topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        })
      end
    end

    test "raises error when toBlock is missing" do
      assert_raise ArgumentError, "toBlock parameter is required", fn ->
        LogsLens.get_logs_by_topics(%{
          fromBlock: 12878196,
          topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        })
      end
    end

    test "raises error when topic format is invalid" do
      assert_raise ArgumentError, ~r/topic0 must be a valid hex string starting with 0x/, fn ->
        LogsLens.get_logs_by_topics(%{
          fromBlock: 12878196,
          toBlock: 12879196,
          topic0: "invalid"
        })
      end
    end

    test "raises error when topic operator is invalid" do
      assert_raise ArgumentError, ~r/topic0_1_opr must be either 'and' or 'or'/, fn ->
        LogsLens.get_logs_by_topics(%{
          fromBlock: 12878196,
          toBlock: 12879196,
          topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          topic1: "0x0000000000000000000000000000000000000000000000000000000000000000",
          topic0_1_opr: "invalid"
        })
      end
    end
  end

  describe "get_logs/1" do
    @tag :integration
    test "fetches event logs by address filtered by topics" do
      # Using the example from the documentation
      address = "0x59728544b08ab483533076417fbbb2fd0b17ce3a"
      from_block = 15073139
      to_block = 15074139
      topic0 = "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
      topic1 = "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b"
      topic0_1_opr = "and"

      result = with_rate_limit(fn ->
        LogsLens.get_logs(%{
          address: address,
          fromBlock: from_block,
          toBlock: to_block,
          topic0: topic0,
          topic1: topic1,
          topic0_1_opr: topic0_1_opr
        })
      end)

      IO.puts("\n=== Event Logs by Address and Topics Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: logs}} = result
      assert is_list(logs)

      # If logs are returned, check their structure
      if length(logs) > 0 do
        first_log = List.first(logs)
        assert is_map(first_log)
        assert Map.has_key?(first_log, "address")
        assert Map.has_key?(first_log, "topics")
        assert Map.has_key?(first_log, "data")
        assert Map.has_key?(first_log, "blockNumber")
      end
    end

    test "raises error when address is missing" do
      assert_raise ArgumentError, "address parameter is required", fn ->
        LogsLens.get_logs(%{
          fromBlock: 15073139,
          toBlock: 15074139,
          topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
        })
      end
    end

    test "raises error when fromBlock is missing" do
      assert_raise ArgumentError, "fromBlock parameter is required", fn ->
        LogsLens.get_logs(%{
          address: "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
          toBlock: 15074139,
          topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
        })
      end
    end

    test "raises error when toBlock is missing" do
      assert_raise ArgumentError, "toBlock parameter is required", fn ->
        LogsLens.get_logs(%{
          address: "0x59728544b08ab483533076417fbbb2fd0b17ce3a",
          fromBlock: 15073139,
          topic0: "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d"
        })
      end
    end
  end
end

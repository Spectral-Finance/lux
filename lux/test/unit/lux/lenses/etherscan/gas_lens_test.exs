defmodule Lux.Lenses.Etherscan.GasLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.GasLens

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

  describe "get_gas_estimate/1" do
    @tag :integration
    test "fetches gas estimate for a valid gas price" do
      # Using a sample gas price in wei
      gas_price = "2000000000" # 2 Gwei

      result = with_rate_limit(fn ->
        GasLens.get_gas_estimate(%{
          gasprice: gas_price
        })
      end)

      IO.puts("\n=== Gas Estimate Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: estimate}} = result
      assert is_binary(estimate)
      # Estimate should be parseable as an integer (seconds)
      {estimate_int, _} = Integer.parse(estimate)
      assert is_integer(estimate_int)
    end

    test "raises error when gas price is missing" do
      assert_raise ArgumentError, "gasprice parameter is required", fn ->
        GasLens.get_gas_estimate(%{})
      end
    end
  end

  describe "get_gas_oracle/0" do
    @tag :integration
    test "fetches current gas oracle data" do
      result = with_rate_limit(fn ->
        GasLens.get_gas_oracle()
      end)

      IO.puts("\n=== Gas Oracle Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: oracle_data}} = result
      assert is_map(oracle_data)

      # Check for expected fields in the response
      assert Map.has_key?(oracle_data, "SafeGasPrice")
      assert Map.has_key?(oracle_data, "ProposeGasPrice")
      assert Map.has_key?(oracle_data, "FastGasPrice")
      assert Map.has_key?(oracle_data, "suggestBaseFee")
      assert Map.has_key?(oracle_data, "gasUsedRatio")
    end
  end

  describe "get_daily_avg_gas_limit/1" do
    @tag :integration
    test "handles daily average gas limit request" do
      # Using a sample date range
      start_date = "2023-01-01"
      end_date = "2023-01-07"

      result = with_rate_limit(fn ->
        GasLens.get_daily_avg_gas_limit(%{
          startdate: start_date,
          enddate: end_date,
          sort: "asc"
        })
      end)

      IO.puts("\n=== Daily Average Gas Limit Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: gas_limit_data}} ->
          assert is_list(gas_limit_data)
          if length(gas_limit_data) > 0 do
            first_item = List.first(gas_limit_data)
            assert is_map(first_item)
            assert Map.has_key?(first_item, "UTCDate")
            assert Map.has_key?(first_item, "unixTimeStamp")
            assert Map.has_key?(first_item, "gasLimit")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        GasLens.get_daily_avg_gas_limit(%{
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate parameter is required", fn ->
        GasLens.get_daily_avg_gas_limit(%{
          startdate: "2023-01-01"
        })
      end
    end

    test "raises error when date format is invalid" do
      assert_raise ArgumentError, "startdate must be in yyyy-MM-dd format, e.g., 2023-01-31", fn ->
        GasLens.get_daily_avg_gas_limit(%{
          startdate: "01/01/2023",
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate must be in yyyy-MM-dd format, e.g., 2023-01-31", fn ->
        GasLens.get_daily_avg_gas_limit(%{
          startdate: "2023-01-01",
          enddate: "01/07/2023"
        })
      end
    end
  end

  describe "get_daily_gas_used/1" do
    @tag :integration
    test "handles daily gas used request" do
      # Using a sample date range
      start_date = "2023-01-01"
      end_date = "2023-01-07"

      result = with_rate_limit(fn ->
        GasLens.get_daily_gas_used(%{
          startdate: start_date,
          enddate: end_date,
          sort: "asc"
        })
      end)

      IO.puts("\n=== Daily Gas Used Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: gas_used_data}} ->
          assert is_list(gas_used_data)
          if length(gas_used_data) > 0 do
            first_item = List.first(gas_used_data)
            assert is_map(first_item)
            assert Map.has_key?(first_item, "UTCDate")
            assert Map.has_key?(first_item, "unixTimeStamp")
            assert Map.has_key?(first_item, "gasUsed")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        GasLens.get_daily_gas_used(%{
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate parameter is required", fn ->
        GasLens.get_daily_gas_used(%{
          startdate: "2023-01-01"
        })
      end
    end
  end

  describe "get_daily_avg_gas_price/1" do
    @tag :integration
    test "handles daily average gas price request" do
      # Using a sample date range
      start_date = "2023-01-01"
      end_date = "2023-01-07"

      result = with_rate_limit(fn ->
        GasLens.get_daily_avg_gas_price(%{
          startdate: start_date,
          enddate: end_date,
          sort: "asc"
        })
      end)

      IO.puts("\n=== Daily Average Gas Price Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      # This endpoint requires a Pro API key, so we'll check for either a successful result
      # or an error indicating that a Pro key is required
      case result do
        {:ok, %{result: gas_price_data}} ->
          assert is_list(gas_price_data)
          if length(gas_price_data) > 0 do
            first_item = List.first(gas_price_data)
            assert is_map(first_item)
            assert Map.has_key?(first_item, "UTCDate")
            assert Map.has_key?(first_item, "unixTimeStamp")
            assert Map.has_key?(first_item, "gasPrice")
          end
        {:error, message} ->
          assert message == "This endpoint requires a Pro API key subscription" ||
                 String.contains?(inspect(message), "API key required") ||
                 String.contains?(inspect(message), "Invalid API Key") ||
                 String.contains?(inspect(message), "Pro")
      end
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        GasLens.get_daily_avg_gas_price(%{
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate parameter is required", fn ->
        GasLens.get_daily_avg_gas_price(%{
          startdate: "2023-01-01"
        })
      end
    end
  end
end

defmodule Lux.Lenses.Etherscan.StatsLensTest do
  use ExUnit.Case, async: false

  alias Lux.Lenses.Etherscan.StatsLens

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
      {:error, message} ->
        assert message == "This endpoint requires a Pro API key subscription" ||
               String.contains?(inspect(message), "API key required") ||
               String.contains?(inspect(message), "Invalid API Key") ||
               String.contains?(inspect(message), "Pro")
      other ->
        flunk("Expected either a successful result or a Pro API error, got: #{inspect(other)}")
    end
  end

  describe "get_eth_supply/0" do
    @tag :integration
    test "fetches total supply of Ether" do
      result = with_rate_limit(fn -> StatsLens.get_eth_supply() end)

      IO.puts("\n=== Ether Supply Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: supply}} = result
      assert is_binary(supply)
      # Supply should be parseable as an integer (wei)
      {supply_int, _} = Integer.parse(supply)
      assert is_integer(supply_int)
    end
  end

  describe "get_eth_supply2/0" do
    @tag :integration
    test "fetches detailed Ether supply data" do
      result = with_rate_limit(fn -> StatsLens.get_eth_supply2() end)

      IO.puts("\n=== Ether Supply 2 Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: supply_data}} = result
      assert is_map(supply_data)

      # Check for expected fields in the response
      assert Map.has_key?(supply_data, "EthSupply")
      assert Map.has_key?(supply_data, "Eth2Staking")
      assert Map.has_key?(supply_data, "BurntFees")
    end
  end

  describe "get_eth_price/0" do
    @tag :integration
    test "fetches current Ether price" do
      result = with_rate_limit(fn -> StatsLens.get_eth_price() end)

      IO.puts("\n=== Ether Price Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: price_data}} = result
      assert is_map(price_data)

      # Check for expected fields in the response
      assert Map.has_key?(price_data, "ethbtc")
      assert Map.has_key?(price_data, "ethbtc_timestamp")
      assert Map.has_key?(price_data, "ethusd")
      assert Map.has_key?(price_data, "ethusd_timestamp")
    end
  end

  describe "get_chain_size/1" do
    @tag :integration
    test "fetches Ethereum blockchain size data" do
      # Using a sample date range and client configuration
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        clienttype: "geth",
        syncmode: "default",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_chain_size(params) end)

      IO.puts("\n=== Ethereum Chain Size Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        StatsLens.get_chain_size(%{
          enddate: "2023-01-07",
          clienttype: "geth",
          syncmode: "default"
        })
      end

      assert_raise ArgumentError, "clienttype parameter is required", fn ->
        StatsLens.get_chain_size(%{
          startdate: "2023-01-01",
          enddate: "2023-01-07",
          syncmode: "default"
        })
      end
    end

    test "raises error when client type is invalid" do
      assert_raise ArgumentError, "clienttype must be either 'geth' or 'parity'", fn ->
        StatsLens.get_chain_size(%{
          startdate: "2023-01-01",
          enddate: "2023-01-07",
          clienttype: "invalid",
          syncmode: "default"
        })
      end
    end

    test "raises error when sync mode is invalid" do
      assert_raise ArgumentError, "syncmode must be either 'default' or 'archive'", fn ->
        StatsLens.get_chain_size(%{
          startdate: "2023-01-01",
          enddate: "2023-01-07",
          clienttype: "geth",
          syncmode: "invalid"
        })
      end
    end
  end

  describe "get_node_count/0" do
    @tag :integration
    test "fetches total number of Ethereum nodes" do
      result = with_rate_limit(fn -> StatsLens.get_node_count() end)

      IO.puts("\n=== Ethereum Node Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert {:ok, %{result: node_count}} = result
      assert is_map(node_count)

      # Check for expected fields in the response
      assert Map.has_key?(node_count, "TotalNodeCount")
    end
  end

  describe "get_daily_txn_fee/1" do
    @tag :integration
    test "handles daily transaction fee request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_txn_fee(params) end)

      IO.puts("\n=== Daily Transaction Fee Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end

    test "raises error when required parameters are missing" do
      assert_raise ArgumentError, "startdate parameter is required", fn ->
        StatsLens.get_daily_txn_fee(%{
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate parameter is required", fn ->
        StatsLens.get_daily_txn_fee(%{
          startdate: "2023-01-01"
        })
      end
    end
  end

  describe "get_daily_new_address/1" do
    @tag :integration
    test "handles daily new address count request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_new_address(params) end)

      IO.puts("\n=== Daily New Address Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_network_utilization/1" do
    @tag :integration
    test "handles daily network utilization request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_network_utilization(params) end)

      IO.puts("\n=== Daily Network Utilization Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_avg_hashrate/1" do
    @tag :integration
    test "handles daily average hash rate request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_avg_hashrate(params) end)

      IO.puts("\n=== Daily Average Hash Rate Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_tx_count/1" do
    @tag :integration
    test "handles daily transaction count request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_tx_count(params) end)

      IO.puts("\n=== Daily Transaction Count Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end
  end

  describe "get_daily_avg_network_difficulty/1" do
    @tag :integration
    test "handles daily average network difficulty request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_daily_avg_network_difficulty(params) end)

      IO.puts("\n=== Daily Average Network Difficulty Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end
  end

  describe "get_eth_historical_price/1" do
    @tag :integration
    test "handles historical ETH price request" do
      # Using a sample date range
      params = %{
        startdate: "2023-01-01",
        enddate: "2023-01-07",
        sort: "asc"
      }

      result = with_rate_limit(fn -> StatsLens.get_eth_historical_price(params) end)

      IO.puts("\n=== Historical ETH Price Response ===")
      IO.puts("Result: #{inspect(result, pretty: true)}")

      assert_success_or_pro_error(result)
    end

    test "raises error when date format is invalid" do
      assert_raise ArgumentError, "startdate must be in yyyy-MM-dd format, e.g., 2023-01-31", fn ->
        StatsLens.get_eth_historical_price(%{
          startdate: "01/01/2023",
          enddate: "2023-01-07"
        })
      end

      assert_raise ArgumentError, "enddate must be in yyyy-MM-dd format, e.g., 2023-01-31", fn ->
        StatsLens.get_eth_historical_price(%{
          startdate: "2023-01-01",
          enddate: "01/07/2023"
        })
      end
    end
  end
end

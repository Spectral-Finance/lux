defmodule Lux.Lenses.Etherscan.GasUsageAnalyticsTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Etherscan.GasUsageAnalytics

  setup do
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  describe "focus/1" do
    test "returns comprehensive gas analytics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v2/api"

        query = URI.decode_query(conn.query_string)
        assert query["module"] == "gastracker"
        assert query["action"] == "gasoracle"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "19000000",
            "SafeGasPrice" => "15",
            "ProposeGasPrice" => "20",
            "FastGasPrice" => "30",
            "suggestBaseFee" => "18.5",
            "gasUsedRatio" => "0.45,0.52,0.61,0.48,0.55"
          }
        })
      end)

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.focus(%{})

      # Current prices
      assert analytics.current_prices.safe_gwei == 15.0
      assert analytics.current_prices.standard_gwei == 20.0
      assert analytics.current_prices.fast_gwei == 30.0
      assert analytics.current_prices.base_fee_gwei == 18.5

      # Network status
      assert analytics.network_status.last_block == 19_000_000
      assert is_number(analytics.network_status.avg_utilization)
      assert analytics.network_status.congestion_level in ["low", "moderate", "high", "very_high", "extreme"]
      assert is_binary(analytics.network_status.congestion_description)

      # Price analysis
      assert analytics.price_analysis.spread_gwei > 0
      assert is_number(analytics.price_analysis.spread_pct)
      assert analytics.price_analysis.volatility_indicator in ["low", "moderate", "high", "extreme"]

      # Cost matrix
      assert is_list(analytics.cost_matrix)
      assert length(analytics.cost_matrix) > 0

      # Recommendations
      assert is_list(analytics.recommendations)
      assert length(analytics.recommendations) > 0
    end

    test "handles high congestion network" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "19000000",
            "SafeGasPrice" => "50",
            "ProposeGasPrice" => "70",
            "FastGasPrice" => "100",
            "suggestBaseFee" => "60.0",
            "gasUsedRatio" => "0.95,0.92,0.98,0.96,0.99"
          }
        })
      end)

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.focus(%{})

      assert analytics.network_status.congestion_level in ["very_high", "extreme"]
      assert analytics.network_status.avg_utilization > 90.0
    end

    test "handles low congestion network" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "19000000",
            "SafeGasPrice" => "5",
            "ProposeGasPrice" => "6",
            "FastGasPrice" => "8",
            "suggestBaseFee" => "4.5",
            "gasUsedRatio" => "0.15,0.12,0.18,0.10,0.14"
          }
        })
      end)

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.focus(%{})

      assert analytics.network_status.congestion_level == "low"
    end

    test "cost matrix includes common operations" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "19000000",
            "SafeGasPrice" => "15",
            "ProposeGasPrice" => "20",
            "FastGasPrice" => "30",
            "suggestBaseFee" => "18.5",
            "gasUsedRatio" => "0.5"
          }
        })
      end)

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.focus(%{})

      operations = Enum.map(analytics.cost_matrix, & &1.operation)
      assert "ETH Transfer" in operations
      assert "ERC20 Transfer" in operations
      assert "DEX Swap" in operations

      Enum.each(analytics.cost_matrix, fn entry ->
        assert entry.cost_slow_eth <= entry.cost_standard_eth
        assert entry.cost_standard_eth <= entry.cost_fast_eth
        assert entry.gas_units > 0
      end)
    end

    test "handles error responses" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "Error",
          "result" => "Invalid API key"
        })
      end)

      assert {:error, _} = GasUsageAnalytics.focus(%{})
    end

    test "handles specific chain ID" do
      Req.Test.expect(Lux.Lens, fn conn ->
        query = URI.decode_query(conn.query_string)
        assert query["chainid"] == "137"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "LastBlock" => "50000000",
            "SafeGasPrice" => "30",
            "ProposeGasPrice" => "35",
            "FastGasPrice" => "50",
            "suggestBaseFee" => "25.0",
            "gasUsedRatio" => "0.6"
          }
        })
      end)

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.focus(%{chainid: 137})

      assert analytics.current_prices.safe_gwei == 30.0
    end
  end

  describe "before_focus/1" do
    test "sets module and action" do
      result = GasUsageAnalytics.before_focus(%{chainid: 1})

      assert result.module == "gastracker"
      assert result.action == "gasoracle"
      assert result.chainid == 1
    end
  end

  describe "after_focus/1" do
    test "processes successful response" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "19000000",
          "SafeGasPrice" => "20",
          "ProposeGasPrice" => "25",
          "FastGasPrice" => "35",
          "suggestBaseFee" => "22.0",
          "gasUsedRatio" => "0.5,0.6"
        }
      }

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.after_focus(response)

      assert analytics.current_prices.safe_gwei == 20.0
      assert analytics.current_prices.standard_gwei == 25.0
      assert analytics.current_prices.fast_gwei == 35.0
      assert analytics.current_prices.base_fee_gwei == 22.0
    end

    test "handles non-numeric values gracefully" do
      response = %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "unavailable",
          "SafeGasPrice" => "unavailable",
          "ProposeGasPrice" => "unavailable",
          "FastGasPrice" => "unavailable",
          "suggestBaseFee" => "unavailable",
          "gasUsedRatio" => "unavailable"
        }
      }

      assert {:ok, %{analytics: analytics}} = GasUsageAnalytics.after_focus(response)

      assert analytics.current_prices.safe_gwei == 0.0
    end

    test "processes error response" do
      response = %{
        "status" => "0",
        "message" => "Error",
        "result" => "Rate limit exceeded"
      }

      assert {:error, _} = GasUsageAnalytics.after_focus(response)
    end
  end

  describe "view/0" do
    test "returns lens struct" do
      lens = GasUsageAnalytics.view()

      assert lens.name == "Etherscan.GasUsageAnalytics"
      assert lens.description =~ "gas usage analytics"
    end
  end
end

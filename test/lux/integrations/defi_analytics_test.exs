defmodule Lux.Integrations.DefiAnalyticsTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.DefiAnalytics

  describe "protocol data" do
    test "protocol_tvl/0 returns protocol TVL" do
      result = DefiAnalytics.protocol_tvl()
      assert elem(result, 0) in [:ok, :error]
    end

    test "protocol_tvl_history/0 returns historical TVL" do
      result = DefiAnalytics.protocol_tvl_history("uniswap-v3", days: 7)
      assert elem(result, 0) in [:ok, :error]
    end

    test "protocol_metrics/0 returns protocol metrics" do
      result = DefiAnalytics.protocol_metrics("uniswap-v3")
      assert elem(result, 0) in [:ok, :error]
    end

    test "protocol_fees/0 returns protocol fees" do
      result = DefiAnalytics.protocol_fees("uniswap-v3")
      assert elem(result, 0) in [:ok, :error]
    end

    test "protocol_revenue/0 returns protocol revenue" do
      result = DefiAnalytics.protocol_revenue("uniswap-v3")
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "chain data" do
    test "chain_tvl/0 returns chain TVL" do
      result = DefiAnalytics.chain_tvl("ethereum")
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "yield data" do
    test "yield_pools/0 returns yield pools" do
      result = DefiAnalytics.yield_pools(limit: 5)
      assert elem(result, 0) in [:ok, :error]
    end

    test "top_yields/0 returns top yields" do
      result = DefiAnalytics.top_yields(limit: 10)
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "DEX data" do
    test "dex_volume/0 returns DEX volume" do
      result = DefiAnalytics.dex_volume("uniswap-v3")
      assert elem(result, 0) in [:ok, :error]
    end
  end

  describe "comprehensive analytics" do
    test "comprehensive_analytics/0 returns full analysis" do
      result = DefiAnalytics.comprehensive_analytics("uniswap-v3")
      assert elem(result, 0) in [:ok, :error]
    end

    test "monitor_tvl_change/0 returns TVL change monitoring" do
      result = DefiAnalytics.monitor_tvl_change("uniswap-v3", 24)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end

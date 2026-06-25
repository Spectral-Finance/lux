defmodule Lux.Lenses.Curve.PoolAnalyticsTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.PoolAnalytics

  describe "view/0" do
    test "returns a properly configured lens" do
      lens = PoolAnalytics.view()
      assert lens.name == "Curve.PoolAnalytics"
      assert lens.method == :get
    end
  end

  describe "after_focus/1" do
    test "processes successful analytics response" do
      response = %{
        "status" => "success",
        "result" => [%{
          "pool_name" => "3crypto",
          "pool_address" => "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
          "tvl" => %{"current" => 150_000_000, "trend" => "up"},
          "volume" => %{"24h" => 5_000_000, "7d_avg" => 4_500_000},
          "revenue" => %{"24h" => 2_500, "7d_avg" => 2_250},
          "feeApr" => 0.5,
          "rewardApr" => 2.3,
          "totalApr" => 2.8,
          "utilization" => 0.75,
          "priceImpact" => %{"1000" => 0.001, "10000" => 0.01}
        }]
      }

      {:ok, result} = PoolAnalytics.after_focus(response)
      assert result.chain == "eth"
      assert length(result.analytics) == 1

      analytics = List.first(result.analytics)
      assert analytics.pool_name == "3crypto"
      assert analytics.fee_apr == 0.5
      assert analytics.reward_apr == 2.3
      assert analytics.total_apr == 2.8
      assert analytics.utilization == 0.75
    end

    test "handles empty analytics response" do
      response = %{"status" => "success", "result" => []}
      {:ok, result} = PoolAnalytics.after_focus(response)
      assert result.analytics == []
    end

    test "handles API error response" do
      response = %{"status" => "error", "error" => "Analytics unavailable"}
      {:error, error_msg} = PoolAnalytics.after_focus(response)
      assert String.contains?(error_msg, "Curve API error")
    end
  end
end

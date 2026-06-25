defmodule Lux.Lenses.Curve.GaugeListTest do
  @moduledoc false
  use UnitAPICase, async: true
  alias Lux.Lenses.Curve.GaugeList

  describe "view/0" do
    test "returns a properly configured lens" do
      lens = GaugeList.view()
      assert lens.name == "Curve.GaugeList"
      assert lens.method == :get
      assert String.contains?(lens.url, "getAllGauges")
    end
  end

  describe "before_focus/1" do
    test "uses default getAllGauges URL" do
      result = GaugeList.before_focus(%{})
      assert %{"url" => url} = result
      assert url == "https://api.curve.fi/v1/getAllGauges"
    end
  end

  describe "after_focus/1" do
    test "processes successful gauge list response" do
      response = %{
        "status" => "success",
        "result" => %{
          "gauges" => [%{
            "id" => "0",
            "address" => "0x000000003988d5541Ab068c586F8Ef090397dA5a",
            "poolId" => 0,
            "poolName" => "3crypto",
            "chain" => "ethereum",
            "symbol" => "crv3crypto",
            "creator" => "0x00000000A2018fE23F3f3Fb0d0f77a95b4b46A07",
            "vote" => 1_000_000_000_000_000_000,
            "supply" => 500_000_000_000_000_000,
            "relativeWeightTarget" => 33,
            "absoluteWeight" => 100_000_000_000_000_000,
            "virtualPrice" => 1_015_000_000_000_000_000,
            "gaugeType" => %{"id" => 0, "name" => "standard"},
            "cpi" => 1.0,
            "apiCpi" => 0.5,
            "inflatorCpi" => 0.5,
            "pool" => %{
              "name" => "3crypto", "symbol" => "crv3crypto",
              "address" => "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
              "gauge_address" => "0x000000003988d5541Ab068c586F8Ef090397dA5a"
            },
            "isKilled" => false
          }]
        }
      }

      {:ok, result} = GaugeList.after_focus(response)
      assert result.chain == "eth"
      assert result.gauge_count == 1
      assert length(result.gauges) == 1

      gauge = List.first(result.gauges)
      assert gauge.pool_name == "3crypto"
      assert gauge.vote == 1_000_000_000_000_000_000
      assert gauge.supply == 500_000_000_000_000_000
      assert gauge.cpi == 1.0
      refute gauge.is_killed
    end

    test "handles API error response" do
      response = %{"status" => "error", "error" => "Failed to fetch gauges"}
      {:error, error_msg} = GaugeList.after_focus(response)
      assert String.contains?(error_msg, "Curve API error")
    end

    test "handles missing gauges key" do
      response = %{"status" => "success", "result" => %{}}
      {:error, error_msg} = GaugeList.after_focus(response)
      assert String.contains?(error_msg, "missing gauges key")
    end
  end
end

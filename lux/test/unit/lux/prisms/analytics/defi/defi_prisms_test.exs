defmodule Lux.Prisms.Analytics.DefiPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Analytics.Defi.ProtocolTvlPrism
  alias Lux.Prisms.Analytics.Defi.YieldPoolsPrism
  alias Lux.Prisms.Analytics.Defi.DexVolumePrism
  alias Lux.Prisms.Analytics.Defi.DuneQueryPrism
  alias Lux.Prisms.Analytics.Defi.DeFiAlertsPrism

  describe "ProtocolTvlPrism" do
    test "parses protocol TVL" do
      input = %{
        protocol_data: %{
          "name" => "MakerDAO",
          "symbol" => "MKR",
          "category" => "CDP",
          "tvl" => "8000000000.0",
          "change_1d" => "0.75"
        }
      }

      assert {:ok, result} = ProtocolTvlPrism.run(input)
      assert result.name == "MakerDAO"
      assert result.total_tvl_usd == 8_000_000_000.0
      assert result.change_1d_pct == 0.75
    end
  end

  describe "YieldPoolsPrism" do
    test "filters yield pools" do
      input = %{
        pools: [
          %{"pool" => "p1", "project" => "curve", "symbol" => "crvUSD", "chain" => "Ethereum", "tvlUsd" => "5000000.0", "apy" => "12.0"}
        ],
        min_tvl_usd: 1_000_000.0,
        min_apy_pct: 10.0
      }

      assert {:ok, result} = YieldPoolsPrism.run(input)
      assert result.pool_count == 1
    end
  end

  describe "DexVolumePrism" do
    test "computes DEX volume metrics" do
      input = %{
        protocols: [
          %{"name" => "Uniswap", "total24h" => 1_200_000_000.0},
          %{"name" => "PancakeSwap", "total24h" => 600_000_000.0}
        ]
      }

      assert {:ok, result} = DexVolumePrism.run(input)
      assert result.total_24h_volume_usd == 1_800_000_000.0
      assert result.top_dex == "Uniswap"
    end
  end

  describe "DuneQueryPrism" do
    test "prepares Dune query execution" do
      input = %{query_id: 998877}
      assert {:ok, result} = DuneQueryPrism.run(input)
      assert result.query_id == 998877
      assert result.state == "prepared_for_execution"
    end
  end

  describe "DeFiAlertsPrism" do
    test "triggers drawdown alert" do
      input = %{
        protocol: "ExploitedProtocol",
        change_1d_pct: -15.0
      }

      assert {:ok, result} = DeFiAlertsPrism.run(input)
      assert result.has_alerts? == true
      assert result.alert_count == 1
    end
  end
end

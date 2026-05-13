defmodule Lux.Integrations.DeFiAnalytics.AnalyticsTest do
  use UnitCase, async: true

  alias Lux.Integrations.DeFiAnalytics.Analytics

  @protocols [
    %{
      "name" => "Aave",
      "slug" => "aave",
      "tvl" => 1_000_000_000,
      "change_1d" => -3,
      "change_7d" => -12
    },
    %{"name" => "Small", "slug" => "small", "tvl" => 10_000, "change_7d" => 5}
  ]

  @yields %{
    "data" => [
      %{
        "pool" => "pool-1",
        "project" => "aave",
        "chain" => "Ethereum",
        "symbol" => "USDC",
        "tvlUsd" => 5_000_000,
        "apy" => 24.5
      },
      %{
        "pool" => "pool-2",
        "project" => "small",
        "chain" => "Polygon",
        "symbol" => "ETH",
        "tvlUsd" => 100_000,
        "apy" => 40.0
      }
    ]
  }

  @volumes %{
    "protocols" => [
      %{
        "name" => "Uniswap",
        "displayName" => "Uniswap",
        "slug" => "uniswap",
        "total24h" => 250_000_000,
        "total7d" => 1_400_000_000,
        "total30d" => 5_500_000_000,
        "change_7d" => -15
      },
      %{
        "name" => "Small DEX",
        "slug" => "small-dex",
        "total24h" => 1_000_000,
        "change_7d" => 2
      }
    ]
  }

  test "processes and ranks protocol metrics" do
    [aave | _] = Analytics.process_protocols(@protocols)

    assert aave.slug == "aave"
    assert aave.tvl_usd == 1_000_000_000
    assert aave.change_7d_pct == -12
  end

  test "processes protocol TVL and volume series" do
    report =
      Analytics.process_protocol(%{
        "name" => "Aave",
        "slug" => "aave",
        "currentChainTvls" => %{"Ethereum" => 100, "Polygon" => 50},
        "totalDataChart" => [[1, 10], [2, 20]],
        "tvl" => [
          %{"date" => 1, "totalLiquidityUSD" => 100},
          %{"date" => 2, "totalLiquidityUSD" => 120}
        ]
      })

    assert report.current_tvl_usd == 150
    assert report.tvl_change_7d_pct == 0.0
    assert [%{volume_usd: 10.0}, %{volume_usd: 20.0}] = report.volume_series
  end

  test "processes DEX volume overview and summary" do
    [uniswap | _] = Analytics.process_volume_overview(@volumes)

    assert uniswap.slug == "uniswap"
    assert uniswap.total_24h_usd == 250_000_000
    assert uniswap.change_7d_pct == -15

    summary =
      Analytics.process_volume_summary(%{
        "name" => "Uniswap",
        "slug" => "uniswap",
        "total24h" => 250_000_000,
        "totalDataChart" => [
          [1, 100],
          [2, 150],
          [3, 200],
          [4, 300],
          [5, 500],
          [6, 800],
          [7, 1_300],
          [8, 2_100]
        ]
      })

    assert summary.total_24h_usd == 250_000_000
    assert summary.volume_change_7d_pct == 2000.0
  end

  test "ranks yield pools by risk adjusted APY" do
    [best | _] = Analytics.yield_analytics(@yields, min_tvl_usd: 1_000_000)

    assert best.pool == "pool-1"
    assert best.risk_adjusted_apy == 24.5
  end

  test "processes Dune result rows" do
    assert [%{"volume" => 10}] =
             Analytics.process_dune_result(%{"result" => %{"rows" => [%{"volume" => 10}]}})
  end

  test "builds dashboard and alerts" do
    dashboard =
      Analytics.dashboard(@protocols, @yields,
        min_yield_apy: 20,
        tvl_drop_pct: 10,
        volumes: @volumes
      )

    assert dashboard.totals.protocols == 2
    assert dashboard.totals.volume_24h_usd == 251_000_000
    assert [%{slug: "aave"} | _] = dashboard.top_protocols
    assert [%{slug: "uniswap"} | _] = dashboard.top_volumes
    assert Enum.any?(dashboard.alerts, &(&1.type == :tvl_drop))
    assert Enum.any?(dashboard.alerts, &(&1.type == :high_yield))
    assert Enum.any?(dashboard.alerts, &(&1.type == :volume_drop))
  end
end

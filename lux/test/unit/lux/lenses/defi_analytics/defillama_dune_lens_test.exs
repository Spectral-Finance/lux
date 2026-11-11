defmodule Lux.Lenses.DefiAnalytics.DefillamaDuneLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.DefiAnalytics.DefillamaDuneLens

  test "analyzes protocol TVL, ranks yield pools, builds Dune queries, and triggers alerts" do
    snapshot = %{
      name: "Aave V3",
      current_tvl_usd: 18_000_000_000.0,
      tvl_7d_ago_usd: 20_500_000_000.0,
      tvl_30d_ago_usd: 16_000_000_000.0,
      mcap_usd: 4_500_000_000.0,
      chain_tvls: %{
        "Ethereum" => 13_500_000_000.0,
        "Arbitrum" => 2_700_000_000.0,
        "Base" => 1_800_000_000.0
      }
    }

    assert {:ok, tvl} = DefillamaDuneLens.analyze_protocol_tvl(snapshot)
    assert tvl.change_7d_pct < -10.0
    assert tvl.chain_dominance_pct["Ethereum"] == 75.0
    assert tvl.mcap_to_tvl == 0.25

    pools = [
      %{pool: "usdc-aave", tvl_usd: 50_000_000.0, apy: 6.5, apy_sigma: 0.5, stablecoin: true},
      %{pool: "eth-uni", tvl_usd: 80_000_000.0, apy: 18.0, apy_sigma: 6.0, stablecoin: false}
    ]

    assert {:ok, [top | _]} = DefillamaDuneLens.rank_yield_pools(pools, stablecoin_only: true)
    assert top.pool == "usdc-aave"
    assert top.risk_adjusted_score == 13.0

    assert {:ok, dune_req} =
             DefillamaDuneLens.build_dune_query(3_412_890, %{"chain" => "base"}, "medium")

    assert dune_req.query_id == 3_412_890

    rows = [
      %{day: "2026-11-09", volume_usd: 100_000_000.0},
      %{day: "2026-11-10", volume_usd: 100_000_000.0},
      %{day: "2026-11-11", volume_usd: 400_000_000.0}
    ]

    assert {:ok, vol} = DefillamaDuneLens.summarize_dex_volume(rows)
    assert vol.volume_spike_ratio == 2.0

    assert {:ok, alerts} = DefillamaDuneLens.evaluate_alerts(tvl, vol)
    assert length(alerts) == 2
  end
end

defmodule Lux.Integration.DeFiAnalyticsWorkflowTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.DeFiAnalytics.Analytics

  @tag :integration
  test "builds analytics dashboard from protocol, yield, and custom query rows" do
    protocols = [
      %{"name" => "Aave", "slug" => "aave", "tvl" => 1_000_000_000, "change_7d" => -12}
    ]

    yields = %{
      "data" => [
        %{
          "pool" => "pool-1",
          "project" => "aave",
          "chain" => "Ethereum",
          "tvlUsd" => 5_000_000,
          "apy" => 24.5
        }
      ]
    }

    dune_rows =
      Analytics.process_dune_result(%{
        "result" => %{"rows" => [%{"protocol" => "aave", "volume_usd" => 250_000_000}]}
      })

    volumes = %{
      "protocols" => [
        %{"name" => "Uniswap", "slug" => "uniswap", "total24h" => 250_000_000, "change_7d" => -15}
      ]
    }

    dashboard =
      Analytics.dashboard(protocols, yields,
        min_yield_apy: 20,
        tvl_drop_pct: 10,
        volumes: volumes
      )

    assert [%{"volume_usd" => 250_000_000}] = dune_rows
    assert dashboard.totals.tvl_usd == 1_000_000_000
    assert dashboard.totals.volume_24h_usd == 250_000_000
    assert [%{pool: "pool-1"}] = dashboard.top_yields
    assert length(dashboard.alerts) == 3
  end
end

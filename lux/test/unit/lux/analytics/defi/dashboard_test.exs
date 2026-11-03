defmodule Lux.Analytics.Defi.DashboardTest do
  use UnitCase, async: true

  alias Lux.Analytics.Defi.Dashboard

  describe "render_tvl_table/1" do
    test "renders TVL overview ASCII table" do
      protocols = [
        %{
          name: "Lido",
          category: "Liquid Staking",
          total_tvl_usd: 25_000_000_000.0,
          change_1d_pct: 1.25,
          chain_tvls: %{"Ethereum" => 25_000_000_000.0}
        },
        %{
          name: "Aave V3",
          category: "Lending",
          total_tvl_usd: 12_000_000_000.0,
          change_1d_pct: -0.5,
          chain_tvls: %{"Ethereum" => 8_000_000_000.0, "Arbitrum" => 4_000_000_000.0}
        }
      ]

      output = Dashboard.render_tvl_table(protocols)

      assert String.contains?(output, "DEFI PROTOCOL TVL & METRICS OVERVIEW")
      assert String.contains?(output, "Lido")
      assert String.contains?(output, "Aave V3")
      assert String.contains?(output, "Liquid Staking")
    end
  end

  describe "render_yield_table/1" do
    test "renders yield leaderboard table" do
      pools = [
        %{
          symbol: "USDC-USDT",
          project: "uniswap-v3",
          chain: "Ethereum",
          tvl_usd: 45_000_000.0,
          apy_pct: 9.2
        }
      ]

      output = Dashboard.render_yield_table(pools)

      assert String.contains?(output, "DEFI YIELD OPPORTUNITIES LEADERBOARD")
      assert String.contains?(output, "USDC-USDT")
      assert String.contains?(output, "uniswap-v3")
    end
  end
end

defmodule Lux.Defi.PancakeSwap.MonitorTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.Monitor

  describe "render_dashboard/1" do
    test "renders ascii table with position rows" do
      farms = [
        %{
          pid: 1,
          chain_name: "BSC",
          pair: "CAKE/BNB",
          staked_usd: 15_000.0,
          pending_cake: 45.2,
          daily_yield_usd: 28.5,
          apy_pct: 68.4,
          status: "ACTIVE"
        },
        %{
          pid: 3,
          chain_name: "Arbitrum",
          pair: "ETH/USDC",
          staked_usd: 50_000.0,
          pending_cake: 12.0,
          daily_yield_usd: 15.0,
          apy_pct: 22.1,
          status: "ACTIVE"
        }
      ]

      output = Monitor.render_dashboard(farms)

      assert String.contains?(output, "PANCAKESWAP MULTI-CHAIN YIELD FARMING DASHBOARD")
      assert String.contains?(output, "CAKE/BNB")
      assert String.contains?(output, "ETH/USDC")
      assert String.contains?(output, "BSC")
      assert String.contains?(output, "Arbitrum")
    end
  end
end

defmodule Lux.Defi.SushiSwap.BridgeMonitorTest do
  use UnitCase, async: true

  alias Lux.Defi.SushiSwap.BridgeMonitor

  describe "verify_bridge_safety/4" do
    test "passes safe transfer quote" do
      # In: 1000 USD, Fee: 5 USD, Out: 994 USD
      # Fee ratio: 0.5%, Slippage: 0.6% (<= 1.0%)
      result = BridgeMonitor.verify_bridge_safety(1000.0, 5.0, 994.0, 1.0)
      assert result.safe? == true
      assert is_nil(result.warning)
    end

    test "flags warning when fee exceeds 5%" do
      # In: 50 USD, Fee: 5 USD (10%)
      result = BridgeMonitor.verify_bridge_safety(50.0, 5.0, 45.0, 1.0)
      assert result.safe? == false
      assert result.warning =~ "Bridge fee exceeds 5%"
    end
  end

  describe "render_dashboard/1" do
    test "renders ASCII cross-chain dashboard" do
      transfers = [
        %{
          src_chain: "Ethereum",
          dst_chain: "Arbitrum",
          token: "USDC",
          amount_in: 5000.0,
          min_amount_out: 4985.0,
          estimated_minutes: 8,
          status: "COMPLETED"
        }
      ]

      output = BridgeMonitor.render_dashboard(transfers)

      assert String.contains?(output, "SUSHIXSWAP CROSS-CHAIN BRIDGE DASHBOARD")
      assert String.contains?(output, "Ethereum -> Arbitrum")
      assert String.contains?(output, "USDC")
    end
  end
end

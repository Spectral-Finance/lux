defmodule Lux.Beams.Trading.HyperliquidBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Trading.Hyperliquid.PerpetualTradingBeam

  describe "run/1" do
    test "executes perpetual trading monitoring beam" do
      input = %{
        coin: "ETH",
        sz: 1.0,
        entry_px: 2500.0,
        mark_px: 2550.0,
        leverage: 10,
        wallet_balance: 5000.0
      }

      assert {:ok, result, execution_log} = PerpetualTradingBeam.run(input)
      assert result.coin == "ETH"
      assert result.direction == "long"
      assert result.unrealized_pnl == 50.0
      assert result.risk_tier in ["safe", "moderate"]
      assert result.derisk_required == false
      assert execution_log.status == :completed
      assert length(execution_log.steps) >= 4
    end
  end
end

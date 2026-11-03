defmodule Lux.Defi.SushiSwap.RouteProcessorTest do
  use UnitCase, async: true

  alias Lux.Defi.SushiSwap.RouteProcessor

  describe "get_amount_out/3" do
    test "computes AMM constant product output with 0.3% fee" do
      # In: 10, Reserve In: 1000, Reserve Out: 2000
      # In with fee = 9970. Num = 9970 * 2000 = 19,940,000
      # Denom = 1000 * 1000 + 9970 = 1,009,970 -> Out = 19.743161
      out = RouteProcessor.get_amount_out(10.0, 1000.0, 2000.0)
      assert out > 19.7 and out < 19.8
    end
  end

  describe "route_multihop/2" do
    test "executes multi-hop route" do
      pools = [
        %{reserve_in: 1000.0, reserve_out: 2000.0},
        %{reserve_in: 2000.0, reserve_out: 4000.0}
      ]

      result = RouteProcessor.route_multihop(10.0, pools)

      assert result.hops == 2
      assert result.amount_out > 38.0
      assert result.price_impact_pct > 0.0
    end
  end
end

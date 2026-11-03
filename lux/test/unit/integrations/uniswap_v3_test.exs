defmodule Lux.Integrations.UniswapV3.LiquidityManagerTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.UniswapV3.LiquidityManager

  test "aligns ticks to fee tier spacing and detects out-of-range positions" do
    assert {:ok, 1980} = LiquidityManager.align_tick(1997, 3000)
    assert {:ok, il_pct} = LiquidityManager.calculate_impermanent_loss_pct(2.0)
    assert il_pct < -5.7 and il_pct > -5.8

    pos = %{current_tick: 2050, tick_lower: 2000, tick_upper: 3000}
    assert LiquidityManager.needs_rebalance?(pos, 60) == true
  end
end

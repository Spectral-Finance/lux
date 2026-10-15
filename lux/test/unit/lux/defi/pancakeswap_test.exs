defmodule Lux.DeFi.PancakeSwapTest do
  use ExUnit.Case, async: true
  alias Lux.DeFi.PancakeSwap

  test "optimizes auto-compound frequency and evaluates farm position" do
    {:ok, opt} =
      PancakeSwap.optimize_auto_compound(%{
        principal_usd: 10_000.0,
        apr: 0.45,
        compound_fee_usd: 0.50
      })

    assert opt.optimized_net_apy > 0.45
    assert opt.optimal_compounds_per_year >= 12

    {:ok, pos} =
      PancakeSwap.evaluate_farm_position(%{
        staked_lp_usd: 5_000.0,
        pending_cake: 10.0,
        cake_price_usd: 2.5,
        impermanent_loss_pct: 1.0,
        min_harvest_usd: 10.0
      })

    assert pos.reward_value_usd == 25.0
    assert pos.should_harvest == true
  end
end

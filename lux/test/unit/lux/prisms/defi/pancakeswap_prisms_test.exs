defmodule Lux.Prisms.Defi.PancakeSwapPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Defi.PancakeSwap.GetPoolApyPrism
  alias Lux.Prisms.Defi.PancakeSwap.StakeFarmPrism
  alias Lux.Prisms.Defi.PancakeSwap.HarvestRewardsPrism
  alias Lux.Prisms.Defi.PancakeSwap.AutoCompoundPrism
  alias Lux.Prisms.Defi.PancakeSwap.BridgeTokensPrism

  describe "GetPoolApyPrism" do
    test "calculates pool yields" do
      input = %{
        tvl_usd: 1_000_000.0,
        daily_vol_usd: 150_000.0,
        cake_price_usd: 2.50
      }

      {:ok, result} = GetPoolApyPrism.run(input)
      assert result.fee_apr_pct > 0.0
      assert result.farming_apr_pct > 0.0
      assert result.compounded_apy_pct > result.total_apr_pct
    end
  end

  describe "StakeFarmPrism" do
    test "simulates deposit into MasterChef" do
      input = %{
        user_address: "0x1111222233334444555566667777888899990000",
        pid: 1,
        amount: 500_000_000_000_000_000,
        current_staked: 0,
        reward_debt: 0
      }

      {:ok, result} = StakeFarmPrism.run(input)
      assert result.new_staked_balance == 500_000_000_000_000_000
      assert result.status == "staked"
    end
  end

  describe "HarvestRewardsPrism" do
    test "harvests pending rewards" do
      input = %{
        user_address: "0x1111222233334444555566667777888899990000",
        pid: 1,
        staked_amount: 1_000_000_000_000_000_000,
        reward_debt: 0,
        acc_cake_per_share: 1_000_000_000_000
      }

      {:ok, result} = HarvestRewardsPrism.run(input)
      assert result.harvested_cake == 1.0
      assert result.status == "harvested"
    end
  end

  describe "AutoCompoundPrism" do
    test "generates compound plan" do
      input = %{
        pending_cake: 25.0,
        cake_price_usd: 2.50,
        price0_usd: 2500.0,
        price1_usd: 1.0,
        gas_cost_usd: 0.50
      }

      {:ok, plan} = AutoCompoundPrism.run(input)
      assert plan.viable? == true
      assert plan.harvest_value_usd == 62.5
    end
  end

  describe "BridgeTokensPrism" do
    test "generates bridge transfer plan" do
      input = %{
        from_chain: 56,
        to_chain: 8453,
        token: "CAKE",
        amount: 50.0,
        recipient: "0x1111222233334444555566667777888899990000",
        token_price_usd: 2.50
      }

      {:ok, plan} = BridgeTokensPrism.run(input)
      assert plan.status == :ready_for_execution
      assert plan.amount == 50.0
      assert plan.to_chain == 8453
    end
  end
end

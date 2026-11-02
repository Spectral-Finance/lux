defmodule Lux.Prisms.Defi.CurvePrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Defi.Curve.{
    AnalyzePoolPrism,
    DepositAndStakePrism,
    ClaimAndCompoundPrism,
    CheckGaugeBoostPrism,
    RebalanceStablePoolPrism
  }

  @unit 1_000_000_000_000_000_000

  describe "AnalyzePoolPrism" do
    test "evaluates pool health and virtual price" do
      input = %{
        pool_id: "3pool",
        balances: [1000 * @unit, 1000 * @unit, 1000 * @unit],
        amp: 2000,
        total_lp_supply: 3000 * @unit
      }

      assert {:ok, res} = AnalyzePoolPrism.run(input)
      assert res.pool_id == "3pool"
      assert res.virtual_price >= 1.0
      assert res.imbalanced == false
      assert res.health_score == 100
    end
  end

  describe "DepositAndStakePrism" do
    test "deposits and auto-stakes into gauge" do
      input = %{
        owner: "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5",
        pool_id: "3pool",
        amounts: [100 * @unit, 100 * @unit, 100 * @unit],
        current_balances: [1000 * @unit, 1000 * @unit, 1000 * @unit],
        amp: 2000,
        total_lp_supply: 3000 * @unit,
        stake_in_gauge: true
      }

      assert {:ok, res} = DepositAndStakePrism.run(input)
      assert is_binary(res.position_id)
      assert res.minted_lp > 0
      assert res.staked_in_gauge == res.minted_lp
      assert res.wallet_lp == 0
    end
  end

  describe "ClaimAndCompoundPrism" do
    test "plans viable auto-compounding harvest" do
      input = %{
        unclaimed_crv: 100.0,
        crv_price_usd: 0.50,
        target_coin: "USDC"
      }

      assert {:ok, res} = ClaimAndCompoundPrism.run(input)
      assert res.crv_amount == 100.0
      assert res.target_coin == "USDC"
      assert res.viable == true
      assert res.estimated_lp_return == 50.0
    end
  end

  describe "CheckGaugeBoostPrism" do
    test "evaluates veCRV boost" do
      input = %{
        user_lp: 1000.0,
        total_gauge_lp: 50_000.0,
        user_vecrv: 500_000.0,
        total_vecrv: 1_000_000.0
      }

      assert {:ok, res} = CheckGaugeBoostPrism.run(input)
      assert res.boost == 2.5
      assert res.max_boosted == true
    end
  end

  describe "RebalanceStablePoolPrism" do
    test "recommends optimal coin deposit" do
      input = %{
        balances: [1000, 500, 1000],
        threshold_pct: 0.05
      }

      assert {:ok, res} = RebalanceStablePoolPrism.run(input)
      assert res.imbalanced == true
      assert res.preferred_deposit_coin_index == 1
      assert res.recommended_action == "deposit_scarce"
    end
  end
end

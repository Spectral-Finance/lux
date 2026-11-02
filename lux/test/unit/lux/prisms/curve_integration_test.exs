defmodule Lux.Prisms.CurveIntegrationTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Curve.{
    ManagePoolPosition,
    GaugeStaking,
    ClaimRewards,
    AnalyzePool,
    RebalancePortfolio
  }

  describe "ManagePoolPosition" do
    test "successfully computes add_liquidity position minting" do
      params = %{
        action: "add_liquidity",
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        amounts: ["1000000000000000000000", "1000000000", "1000000000"],
        min_mint_amount: "2900000000000000000000"
      }

      assert {:ok, result} = ManagePoolPosition.handler(params, %{name: "TestAgent"})
      assert result.success == true
      assert result.action == "add_liquidity"
      assert is_binary(result.lp_tokens_affected)
      assert result.transaction_receipt["effective_slippage_bps"] == 5
    end

    test "handles single-sided liquidity removal" do
      params = %{
        action: "remove_liquidity_one_coin",
        pool_address: "0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7",
        min_mint_amount: "500000000000000000000",
        coin_index: 1
      }

      assert {:ok, result} = ManagePoolPosition.handler(params, %{name: "TestAgent"})
      assert result.success == true
      assert result.action == "remove_liquidity_one_coin"
      assert result.transaction_receipt["target_coin_index"] == 1
    end
  end

  describe "GaugeStaking" do
    test "calculates baseline 1.0x boost without veCRV" do
      params = %{
        action: "deposit",
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        amount: "1000000000000000000000"
      }

      assert {:ok, result} = GaugeStaking.handler(params, %{name: "TestAgent"})
      assert result.success == true
      assert result.boost_multiplier == 1.0
    end

    test "calculates amplified boost with active veCRV voting weight" do
      params = %{
        action: "calculate_boost",
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        amount: "1000000000000000000000",
        user_vecrv_balance: "5000000000000000000000000",
        total_vecrv_supply: "100000000000000000000000000"
      }

      assert {:ok, result} = GaugeStaking.handler(params, %{name: "TestAgent"})
      assert result.boost_multiplier > 1.0
      assert result.boost_multiplier <= 2.5
    end
  end

  describe "ClaimRewards" do
    test "approves claim when gross reward exceeds profitability hurdle" do
      params = %{
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        min_reward_usd_value: 10.0,
        crv_price_usd: 0.60,
        gas_cost_usd: 4.00
      }

      assert {:ok, result} = ClaimRewards.handler(params, %{name: "TestAgent"})
      assert result.claimed == true
      assert result.net_profit_usd == 26.00
    end

    test "skips claim when gas exceeds value" do
      params = %{
        gauge_address: "0xbFcF63294aD7105dEa65aA58F8AE5BE2D9d0952A",
        min_reward_usd_value: 100.0,
        crv_price_usd: 0.50,
        gas_cost_usd: 5.00
      }

      assert {:ok, result} = ClaimRewards.handler(params, %{name: "TestAgent"})
      assert result.claimed == false
      assert String.contains?(result.skip_reason, "below minimum profitability")
    end
  end

  describe "AnalyzePool & RebalancePortfolio" do
    test "analyzes 3pool virtual price and invariant health" do
      assert {:ok, analysis} = AnalyzePool.handler(%{pool_id: "3pool"}, %{})
      assert analysis.virtual_price > 1.0
      assert analysis.peg_health == "OPTIMAL_INVARIANT"
      assert analysis.a_parameter == 2000
    end

    test "recommends rebalancing when yield delta covers slippage" do
      params = %{
        source_pool_id: "3pool",
        target_pool_id: "crvusd-usdc",
        amount_usd: 50_000.0,
        max_allowed_slippage_bps: 20,
        min_apy_delta_pct: 2.0
      }

      assert {:ok, plan} = RebalancePortfolio.handler(params, %{})
      assert plan.rebalance_recommended == true
      assert plan.apy_gain_pct == 5.75
      assert plan.payback_days < 10.0
    end
  end
end

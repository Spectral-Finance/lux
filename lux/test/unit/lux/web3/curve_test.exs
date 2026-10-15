defmodule Lux.Web3.Exchanges.CurveTest do
  use ExUnit.Case, async: false

  alias Lux.Prisms.Web3.CurvePrism
  alias Lux.Web3.Exchanges.Curve

  @wallet "0x71c0000000000000000000000000000000000081"

  setup do
    Curve.reset_state!()
    :ok
  end

  describe "pool discovery and registry" do
    test "lists StableSwap and CryptoSwap pools with filtering" do
      assert {:ok, all_pools} = Curve.list_pools()
      assert length(all_pools) >= 4

      assert {:ok, stable_pools} = Curve.list_pools(pool_type: :stableswap)
      assert Enum.all?(stable_pools, &(&1.pool_type == :stableswap))

      assert {:ok, frax_pools} = Curve.list_pools(coin: "FRAX")
      assert Enum.map(frax_pools, & &1.id) == ["frax_usdc"]
    end

    test "retrieves specific pool details or returns error when missing" do
      assert {:ok, pool} = Curve.get_pool("3pool")
      assert pool.coins == ["DAI", "USDC", "USDT"]
      assert pool.amplification == 2000

      assert {:error, :pool_not_found} = Curve.get_pool("unknown_pool")
    end
  end

  describe "get_dy swap quoting, routing, and execution" do
    test "calculates low-slippage StableSwap get_dy quote and CryptoSwap quote" do
      assert {:ok, quote_3pool} = Curve.get_dy("3pool", "USDC", "USDT", 100_000)
      assert quote_3pool.dy > 99_900.0
      assert quote_3pool.fee_amount > 0
      assert quote_3pool.price_impact_bps < 10.0

      assert {:ok, quote_crypto} = Curve.get_dy("tricrypto2", "USDT", "WETH", 30_000)
      assert quote_crypto.dy > 9.9
      assert quote_crypto.pool_type == :cryptoswap
    end

    test "finds best swap route across multiple Curve pools" do
      assert {:ok, route} = Curve.find_best_route("USDC", "USDT", 50_000, max_slippage_bps: 30)
      assert route.best_pool_id == "3pool"
      assert route.expected_dy > route.min_dy
      assert is_list(route.alternatives)
    end

    test "executes slippage-protected swap and rejects when min_dy is not met" do
      assert {:ok, receipt} =
               Curve.execute_swap("3pool", "USDC", "DAI", 10_000, 9_950, wallet: @wallet)

      assert String.starts_with?(receipt.tx_hash, "0x")
      assert receipt.dy >= 9_950

      assert {:error, :slippage_exceeded} =
               Curve.execute_swap("3pool", "USDC", "DAI", 10_000, 10_050, wallet: @wallet)
    end
  end

  describe "liquidity provision, gauge staking, and CRV reward optimization" do
    test "adds and removes liquidity in balanced and single-coin modes" do
      assert {:ok, add_res} =
               Curve.add_liquidity("3pool", [10_000, 10_000, 10_000], 28_000, wallet: @wallet)

      assert add_res.lp_tokens_minted > 28_000
      assert add_res.imbalance_penalty_bps == 0.0

      assert {:ok, rem_one} =
               Curve.remove_liquidity("3pool", 5_000, {:one_coin, "USDC"}, wallet: @wallet)

      assert Map.has_key?(rem_one.withdrawn, "USDC")
      assert rem_one.remaining_lp_balance < add_res.lp_tokens_minted

      assert {:ok, rem_bal} =
               Curve.remove_liquidity("3pool", 5_000, :balanced, wallet: @wallet)

      assert Map.keys(rem_bal.withdrawn) |> Enum.sort() == ["DAI", "USDC", "USDT"]
    end

    test "stakes LP in gauge with veCRV boost, claims CRV rewards, and compounds" do
      {:ok, add_res} =
        Curve.add_liquidity("3pool", [20_000, 20_000, 20_000], 50_000, wallet: @wallet)

      assert {:ok, stake_res} =
               Curve.stake_in_gauge("3pool", add_res.lp_tokens_minted,
                 wallet: @wallet,
                 vecrv_balance: 250_000.0
               )

      assert stake_res.boost_multiplier > 1.0
      assert stake_res.boost_multiplier <= 2.5
      assert stake_res.total_effective_apy > stake_res.base_apy

      assert {:ok, claim_res} =
               Curve.claim_rewards("3pool",
                 wallet: @wallet,
                 days_elapsed: 30,
                 compound: true
               )

      assert claim_res.crv_claimed > 0.0
      assert claim_res.compounded == true
      assert claim_res.compounded_lp_added > 0.0

      assert {:ok, unstake_res} =
               Curve.unstake_from_gauge("3pool", 10_000, wallet: @wallet)

      assert unstake_res.wallet_lp_balance == 10_000.0
    end
  end

  describe "stablecoin peg monitoring and automated yield rebalancing" do
    test "detects healthy peg vs critical depeg skew and recommends rebalancing" do
      assert {:ok, healthy} = Curve.analyze_peg_health("3pool")
      assert healthy.status == :healthy

      {:ok, pool} = Curve.get_pool("3pool")
      Curve.register_pool(%{pool | balances: [120_000_000.0, 10_000_000.0, 10_000_000.0]})

      assert {:ok, depegged} = Curve.analyze_peg_health("3pool")
      assert depegged.status == :critical_depeg
      assert depegged.dominant_coin == "DAI"

      Curve.add_liquidity("3pool", [5_000, 5_000, 5_000], 0, wallet: @wallet)
      assert {:ok, plan} = Curve.optimize_yield_rebalance(@wallet)
      assert plan.optimal_pool.pool_id != "3pool"
      assert Enum.any?(plan.recommended_actions, &(&1.action == :emergency_exit))
    end
  end

  describe "CurvePrism handler" do
    test "dispatches Curve operations through Prism interface" do
      assert {:ok, %{status: "ok", data: %{pools: pools}}} =
               CurvePrism.handler(%{action: "list_pools", pool_type: "stableswap"}, %{})

      assert length(pools) >= 3

      assert {:ok, %{status: "ok", data: quote_data}} =
               CurvePrism.handler(
                 %{action: "get_dy", pool_id: "3pool", from_coin: "USDC", to_coin: "USDT", dx: 1000},
                 %{}
               )

      assert quote_data.dy > 999.0

      assert {:ok, %{status: "ok", data: health}} =
               CurvePrism.handler(%{action: "analyze_peg_health", pool_id: "frax_usdc"}, %{})

      assert health.status == :healthy
    end
  end
end

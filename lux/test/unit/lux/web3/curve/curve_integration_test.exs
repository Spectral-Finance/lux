defmodule Lux.Web3.Curve.CurveIntegrationTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Contracts.CurveV2CRV
  alias Lux.Web3.Contracts.CurveV2Gauge
  alias Lux.Web3.Contracts.CurveV2Pool
  alias Lux.Web3.Curve.PoolAnalysis
  alias Lux.Web3.Curve.Rebalancer
  alias Lux.Web3.Curve.Rewards
  alias Lux.Web3.Curve.Slippage

  @virtual_price 1_000_000_000_000_000_000

  describe "regression: Curve Finance integration surface" do
    test "the Curve V2 contract modules are available and export their ABI functions" do
      # Calling directly so that, on unpatched code, the run fails with a
      # deterministic "(module ... is not available)" error.
      assert CurveV2Pool.name() != nil
      assert function_exported?(CurveV2Pool, :get_dy, 3)
      assert function_exported?(CurveV2Pool, :minter, 0)

      assert CurveV2Gauge.working_supply() != nil
      assert function_exported?(CurveV2Gauge, :earned, 1)

      assert CurveV2CRV.total_supply() != nil
      assert function_exported?(CurveV2CRV, :balance_of, 1)
    end

    test "pool analysis selects the best stablecoin pool" do
      balanced = %{
        address: "0xaaa",
        balances: [1_000_000, 1_000_000],
        virtual_price: @virtual_price,
        fee: 1_000_000,
        crv_reward_rate: 1_000_000_000_000_000_000
      }

      imbalanced = %{
        address: "0xbbb",
        balances: [9_000_000, 1_000_000],
        virtual_price: @virtual_price,
        fee: 4_000_000
      }

      assert {:ok, %{address: "0xaaa", recommendation: :provide_liquidity}} =
               PoolAnalysis.select_best([imbalanced, balanced])
    end

    test "slippage, rebalancing and reward helpers cooperate end to end" do
      assert {:ok, min_out} = Slippage.min_received(10_000_000, 100)
      assert Slippage.acceptable?(9_950_000, min_out)

      assert {:ok, [%{pool: :three_pool, action: :deposit, amount: 1_000}]} =
               Rebalancer.plan(%{three_pool: 0}, %{three_pool: 10_000}, 1_000)

      assert {:ok, %{decision: :claim}} =
               Rewards.should_claim?(100, 2_000_000_000_000_000_000, 1)
    end
  end
end

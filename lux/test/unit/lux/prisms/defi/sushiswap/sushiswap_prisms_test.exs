defmodule Lux.Prisms.Defi.SushiSwapPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Defi.SushiSwap.SushiPoolPrism
  alias Lux.Prisms.Defi.SushiSwap.SushiXSwapPrism
  alias Lux.Prisms.Defi.SushiSwap.MiniChefStakePrism
  alias Lux.Prisms.Defi.SushiSwap.RouteProcessorPrism
  alias Lux.Prisms.Defi.SushiSwap.BridgeSecurityPrism

  describe "SushiPoolPrism" do
    test "builds pool state" do
      input = %{
        chain_id: 1,
        token0: "SUSHI",
        token1: "WETH",
        reserve0: 500_000.0,
        reserve1: 150.0
      }

      assert {:ok, result} = SushiPoolPrism.run(input)
      assert result.chain_id == 1
      assert result.mid_price > 0.0
    end
  end

  describe "SushiXSwapPrism" do
    test "quotes cross-chain route" do
      input = %{
        src_chain: 1,
        dst_chain: 42161,
        src_token: "WETH",
        dst_token: "USDC",
        amount_in: 2.0,
        src_price_usd: 2500.0,
        dst_price_usd: 1.0
      }

      assert {:ok, result} = SushiXSwapPrism.run(input)
      assert result.src_chain == 1
      assert result.estimated_amount_out > 4900.0
    end
  end

  describe "MiniChefStakePrism" do
    test "simulates staking" do
      input = %{
        user_address: "0x123",
        pid: 1,
        amount: 1_000_000_000_000_000_000
      }

      assert {:ok, result} = MiniChefStakePrism.run(input)
      assert result.new_staked_balance == 1_000_000_000_000_000_000
      assert result.status == "staked"
    end
  end

  describe "RouteProcessorPrism" do
    test "routes swap" do
      input = %{
        amount_in: 100.0,
        pools: [%{reserve_in: 10000.0, reserve_out: 20000.0}]
      }

      assert {:ok, result} = RouteProcessorPrism.run(input)
      assert result.hops == 1
      assert result.amount_out > 195.0
    end
  end

  describe "BridgeSecurityPrism" do
    test "checks safety" do
      input = %{
        amount_in_usd: 500.0,
        fee_usd: 2.5,
        est_out_usd: 497.0
      }

      assert {:ok, result} = BridgeSecurityPrism.run(input)
      assert result.safe? == true
    end
  end
end

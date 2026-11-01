defmodule Lux.Defi.SushiSwapTest do
  use ExUnit.Case, async: true
  alias Lux.Defi.SushiSwap

  describe "SushiSwap Multi-Chain & Cross-Chain Integration (#80)" do
    test "retrieves supported chains and Stargate IDs" do
      chains = SushiSwap.supported_chains()
      assert :arbitrum in chains
      assert :base in chains

      assert {:ok, 110} = SushiSwap.stargate_chain_id(:arbitrum)
      assert {:ok, 184} = SushiSwap.stargate_chain_id(:base)
      assert {:error, :unsupported_chain} = SushiSwap.stargate_chain_id(:solana)
    end

    test "selects optimal cross-chain bridge route maximizing net output" do
      req = %{source_chain: :arbitrum, dest_chain: :base, amount_in: 1000.0, slippage_bps: 50}

      routes = [
        %{adapter: :stargate, bridge_fee_usd: 1.5, exchange_rate: 1.0, estimated_time_sec: 45},
        %{adapter: :axelar, bridge_fee_usd: 5.0, exchange_rate: 1.0, estimated_time_sec: 90}
      ]

      {:ok, best} = SushiSwap.quote_cross_chain_swap(req, routes)
      assert best.adapter == :stargate
      assert best.source_chain == :arbitrum
      assert best.dest_chain == :base
      assert best.net_output > 990.0
    end

    test "rejects same-chain or invalid chain swaps" do
      assert {:error, :same_chain_swap_use_local_router} =
               SushiSwap.quote_cross_chain_swap(
                 %{source_chain: :base, dest_chain: :base, amount_in: 100.0},
                 [%{adapter: :local}]
               )

      assert {:error, {:unsupported_source_chain, :fantom}} =
               SushiSwap.quote_cross_chain_swap(
                 %{source_chain: :fantom, dest_chain: :base, amount_in: 100.0},
                 [%{adapter: :stargate}]
               )
    end

    test "estimates liquidity provision shares and annual yield" do
      {:ok, stats} = SushiSwap.estimate_liquidity_provision(100.0, 300_000.0, 900.0, 50_000.0)
      assert stats.pool_share_pct == 10.0
      assert stats.estimated_annual_reward_usd == 5000.0
    end

    test "verifies bridge health metrics" do
      assert {:ok, :healthy} =
               SushiSwap.verify_bridge_safety(%{recent_failure_rate: 0.01, average_latency_sec: 45})

      assert {:error, :bridge_degraded} =
               SushiSwap.verify_bridge_safety(%{recent_failure_rate: 0.12, average_latency_sec: 600})
    end
  end
end

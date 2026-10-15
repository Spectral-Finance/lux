defmodule Lux.Web3.GasOptimizerTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.Web3.GasOptimizerPrism
  alias Lux.Web3.GasOptimizer

  setup do
    GasOptimizer.reset!()
    Application.put_env(:lux, GasOptimizer, plug: {Req.Test, GasOptimizer})
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "EIP-1559 gas fee prediction and priority fee optimization" do
    test "predicts gas fees across economy, standard, fast, and urgent tiers" do
      fee_history_resp = %{
        "baseFeePerGas" => [
          "0x4a817c800",
          "0x4e3b29200",
          "0x51f4d5c00"
        ],
        "gasUsedRatio" => [0.75, 0.85],
        "reward" => [
          ["0x3b9aca00", "0x59682f00", "0x9502f900", "0x12a05f200"],
          ["0x3b9aca00", "0x77359400", "0xb2d05e00", "0x165a0bc00"]
        ]
      }

      Req.Test.expect(GasOptimizer, 2, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_feeHistory"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => decoded["id"],
          "result" => fee_history_resp
        })
      end)

      {:ok, econ} = GasOptimizer.predict_gas_fees(:ethereum, :economy)
      {:ok, urgent} = GasOptimizer.predict_gas_fees(:ethereum, :urgent)

      assert econ.trend == :rising
      assert urgent.max_fee_per_gas_wei > econ.max_fee_per_gas_wei
      assert urgent.max_priority_fee_per_gas_wei > econ.max_priority_fee_per_gas_wei
    end
  end

  describe "Multicall3 transaction batching and gas savings" do
    test "bundles multiple calls into a Multicall3 payload and calculates saved gas" do
      calls = [
        %{
          to: "0x1111111111111111111111111111111111111111",
          value: 0,
          data: "0xa9059cbb",
          gas_estimate: 45_000
        },
        %{
          to: "0x2222222222222222222222222222222222222222",
          value: 0,
          data: "0xa9059cbb",
          gas_estimate: 45_000
        },
        %{
          to: "0x3333333333333333333333333333333333333333",
          value: 0,
          data: "0xa9059cbb",
          gas_estimate: 45_000
        }
      ]

      {:ok, batch} = GasOptimizer.build_batch(calls)
      assert batch.call_count == 3
      assert batch.gas_saved > 30_000
      assert batch.savings_percentage > 15.0
      assert String.starts_with?(batch.data, "0x174dea71")
    end
  end

  describe "Transaction replacement (speed_up & cancel) and MEV protection" do
    test "creates valid Replace-By-Fee speed_up and cancel transactions" do
      pending = %{
        from: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        to: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        value: 1_000_000_000_000_000_000,
        data: "0x38ed17390000",
        nonce: 7,
        max_fee_per_gas: 30_000_000_000,
        max_priority_fee_per_gas: 2_000_000_000
      }

      {:ok, sped_up} = GasOptimizer.speed_up(pending, bump_ratio: 1.20)
      assert sped_up.nonce == 7
      assert sped_up.max_fee_per_gas == 36_000_000_000
      assert sped_up.max_priority_fee_per_gas == 2_400_000_000
      assert sped_up.replacement_type == :speed_up

      {:ok, cancelled} = GasOptimizer.cancel(pending, bump_ratio: 1.20)
      assert cancelled.nonce == 7
      assert cancelled.to == pending.from
      assert cancelled.value == 0
      assert cancelled.data == "0x"
      assert cancelled.replacement_type == :cancel

      assert {:error, :insufficient_fee_bump} =
               GasOptimizer.speed_up(pending, bump_ratio: 1.02)
    end

    test "detects high MEV risk on large DEX swaps and builds private relay bundles" do
      swap_tx = %{
        chain: :ethereum,
        value: 25_000_000_000_000_000_000,
        data: "0x38ed1739" <> String.duplicate("0", 140)
      }

      risk = GasOptimizer.analyze_mev_risk(swap_tx)
      assert risk.is_dex_swap == true
      assert risk.risk_level == :high
      assert risk.use_private_mempool == true
      assert risk.recommended_max_slippage_bps == 30
      assert risk.private_relays != []

      bundle = GasOptimizer.build_private_bundle(["0x02f8..."], 19_500_000)
      assert bundle["method"] == "eth_sendBundle"
    end
  end

  describe "Transaction simulation, cost reporting, and GasOptimizerPrism" do
    test "simulates pre-flight execution and tracks gas cost & savings" do
      Req.Test.expect(GasOptimizer, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x01"})
      end)

      Req.Test.expect(GasOptimizer, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 2, "result" => "0xafc8"})
      end)

      {:ok, sim} =
        GasOptimizer.simulate_transaction(%{
          chain: :ethereum,
          from: "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          to: "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          value: 0,
          data: "0xa9059cbb"
        })

      assert sim.success == true
      assert sim.estimated_gas == 45_000

      {:ok, _} =
        GasOptimizer.record_gas_usage(%{
          chain: :ethereum,
          tx_hash: "0xtx1",
          gas_used: 95_000,
          gas_saved: 34_200,
          effective_gas_price_wei: 20_000_000_000,
          native_token_usd: 3_000.0
        })

      {:ok, report} = GasOptimizerPrism.handler(%{"action" => "cost_report"}, nil)
      assert report.transaction_count == 1
      assert report.total_gas_saved == 34_200
      assert report.total_saved_usd > 0.0
    end
  end
end

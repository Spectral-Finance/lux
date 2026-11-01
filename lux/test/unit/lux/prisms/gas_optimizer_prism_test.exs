defmodule Lux.Prisms.GasOptimizerPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.GasOptimizerPrism

  describe "GasOptimizerPrism handler/2" do
    test "predicts gas fees for standard tier" do
      {:ok, response} =
        GasOptimizerPrism.run(%{
          action: "predict",
          payload: %{tier: "standard"}
        })

      assert response.action == "predict"
      assert is_map(response.result)
      assert response.result.base_fee_gwei > 0
      assert response.result.max_priority_fee_gwei > 0
    end

    test "bundles calls via batch action" do
      calls = [
        %{target: "0x1111111111111111111111111111111111111111", call_data: "0xaa"},
        %{target: "0x2222222222222222222222222222222222222222", call_data: "0xbb"}
      ]

      {:ok, response} =
        GasOptimizerPrism.run(%{
          action: "batch",
          payload: %{calls: calls}
        })

      assert response.action == "batch"
      assert response.result.calls_count == 2
      assert response.result.gas_saved > 0
    end

    test "handles speed_up action" do
      tx = %{
        nonce: 10,
        from: "0x1111111111111111111111111111111111111111",
        to: "0x2222222222222222222222222222222222222222",
        max_fee_per_gas: 20_000_000_000,
        max_priority_fee_per_gas: 1_500_000_000
      }

      {:ok, response} =
        GasOptimizerPrism.run(%{
          action: "speed_up",
          payload: %{tx: tx, bump_multiplier: 1.20}
        })

      assert response.action == "speed_up"
      assert response.result.max_fee_per_gas > tx.max_fee_per_gas
    end

    test "performs mev_check" do
      {:ok, response} =
        GasOptimizerPrism.run(%{
          action: "mev_check",
          payload: %{action_type: :swap, slippage_percentage: 2.5}
        })

      assert response.action == "mev_check"
      assert response.result.risk_level == :critical
      assert response.result.requires_private_relay == true
    end

    test "performs full optimize pipeline" do
      tx = %{
        estimated_gas: 65_000,
        action_type: :transfer,
        slippage_percentage: 0.1
      }

      {:ok, response} =
        GasOptimizerPrism.run(%{
          action: "optimize",
          payload: tx
        })

      assert response.action == "optimize"
      assert response.result.status == :ready
      assert response.result.recommended_execution.gas_limit > 65_000
    end
  end
end

defmodule Lux.Prisms.Web3.GasTransactionManagerTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.GasTransactionManager

  @ctx %{agent: %{name: "GasAgent"}}

  test "dispatches gas prediction through the prism" do
    assert {:ok, %{status: "success", result: result}} =
             GasTransactionManager.handler(
               %{
                 action: "predict_gas",
                 params: %{
                   observations: %{
                     base_fee_per_gas: "30 gwei",
                     priority_fee_per_gas: "2 gwei",
                     gas_used_ratio: 0.7
                   }
                 }
               },
               @ctx
             )

    assert result.selected_tier == :standard
    assert result.selected.max_fee_per_gas > 0
  end

  test "dispatches management plans through the prism" do
    assert {:ok, %{status: "success", result: result}} =
             GasTransactionManager.handler(
               %{
                 action: "management_plan",
                 params: %{
                   observations: %{
                     base_fee_per_gas: "20 gwei",
                     priority_fee_per_gas: "1 gwei",
                     gas_used_ratio: 0.5
                   },
                   account_balance_wei: 10_000_000_000_000_000,
                   transactions: [
                     %{
                       from: "0x1111111111111111111111111111111111111111",
                       to: "0x2222222222222222222222222222222222222222",
                       nonce: 1,
                       gas_limit: 21_000,
                       value_wei: 0,
                       data: "0x"
                     }
                   ],
                   mev: %{risk: :medium}
                 }
               },
               @ctx
             )

    assert result.ready
    assert result.batching.transaction_count == 1
    assert result.gas_token_strategy.status == :funded
    assert result.cost_report.transaction_count == 1
  end

  test "rejects unsupported actions" do
    assert {:error, "Unsupported Web3 gas transaction operation"} =
             GasTransactionManager.handler(%{action: "unknown"}, @ctx)
  end
end

defmodule Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.EIP1559FeeCalculatorPrism

  setup do
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  defp mock_gas_oracle do
    Req.Test.expect(Lux.Lens, fn conn ->
      Req.Test.json(conn, %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "19000000",
          "SafeGasPrice" => "15",
          "ProposeGasPrice" => "20",
          "FastGasPrice" => "30",
          "suggestBaseFee" => "18.5",
          "gasUsedRatio" => "0.45,0.52,0.61,0.48,0.55"
        }
      })
    end)
  end

  describe "handler/2 - calculate action" do
    test "calculates EIP-1559 fees with explicit base fee" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "calculate",
                   urgency: "medium",
                   current_base_fee_gwei: 20.0,
                   gas_used_ratios: "0.5,0.6,0.55"
                 },
                 nil
               )

      assert is_number(result.base_fee_gwei)
      assert result.base_fee_gwei == 20.0
      assert is_number(result.max_priority_fee_gwei)
      assert result.max_priority_fee_gwei > 0
      assert is_number(result.max_fee_per_gas_gwei)
      assert result.max_fee_per_gas_gwei > result.base_fee_gwei
      assert result.urgency == "medium"
    end

    test "calculates fees for all urgency levels" do
      urgencies = ["low", "medium", "high", "urgent"]

      results =
        Enum.map(urgencies, fn urgency ->
          {:ok, result} =
            EIP1559FeeCalculatorPrism.handler(
              %{
                action: "calculate",
                urgency: urgency,
                current_base_fee_gwei: 20.0,
                gas_used_ratios: "0.5"
              },
              nil
            )

          {urgency, result}
        end)

      # Higher urgency should have higher priority fees
      fees = Enum.map(results, fn {_, r} -> r.max_priority_fee_gwei end)
      assert Enum.sort(fees) == fees
    end

    test "auto-fetches gas data from network when not provided" do
      mock_gas_oracle()

      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{action: "calculate", urgency: "medium"},
                 nil
               )

      assert is_number(result.base_fee_gwei)
      assert is_number(result.max_fee_per_gas_gwei)
    end

    test "calculates savings vs legacy pricing" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "calculate",
                   urgency: "medium",
                   current_base_fee_gwei: 20.0,
                   gas_used_ratios: "0.5"
                 },
                 nil
               )

      assert is_number(result.fee_savings_vs_legacy_pct)
    end
  end

  describe "handler/2 - bump action" do
    test "bumps fees by minimum 10%" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "bump",
                   original_max_fee_gwei: 20.0,
                   original_priority_fee_gwei: 2.0
                 },
                 nil
               )

      assert result.action == "bump"
      assert result.bumped_max_fee_gwei >= 20.0 * 1.10
      assert result.bumped_priority_fee_gwei >= 2.0 * 1.10
      assert result.bump_percentage == 10.0
    end

    test "returns error when missing original fees" do
      assert {:error, msg} =
               EIP1559FeeCalculatorPrism.handler(
                 %{action: "bump"},
                 nil
               )

      assert msg =~ "original_max_fee_gwei"
    end

    test "preserves original fee values in response" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "bump",
                   original_max_fee_gwei: 25.0,
                   original_priority_fee_gwei: 3.0
                 },
                 nil
               )

      assert result.original_max_fee_gwei == 25.0
      assert result.original_priority_fee_gwei == 3.0
    end
  end

  describe "handler/2 - predict action" do
    test "predicts base fees for future blocks" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "predict",
                   current_base_fee_gwei: 20.0,
                   gas_used_ratios: "0.5,0.6,0.55",
                   prediction_blocks: 5
                 },
                 nil
               )

      assert length(result.predicted_base_fees) == 5
      assert is_number(result.current_base_fee_gwei)
      assert result.prediction_blocks == 5
      assert result.trend in ["increasing", "decreasing", "stable"]
    end

    test "predicts increasing fees when utilization is high" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "predict",
                   current_base_fee_gwei: 20.0,
                   gas_used_ratios: "0.9,0.95,0.92",
                   prediction_blocks: 3
                 },
                 nil
               )

      # With high utilization, fees should increase
      assert List.last(result.predicted_base_fees) > result.current_base_fee_gwei
    end

    test "predicts decreasing fees when utilization is low" do
      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{
                   action: "predict",
                   current_base_fee_gwei: 40.0,
                   gas_used_ratios: "0.1,0.15,0.12",
                   prediction_blocks: 3
                 },
                 nil
               )

      # With low utilization, fees should decrease
      assert List.last(result.predicted_base_fees) < result.current_base_fee_gwei
    end

    test "auto-fetches when no data provided" do
      mock_gas_oracle()

      assert {:ok, result} =
               EIP1559FeeCalculatorPrism.handler(
                 %{action: "predict", prediction_blocks: 3},
                 nil
               )

      assert length(result.predicted_base_fees) == 3
    end
  end

  describe "predict_next_base_fee/2" do
    test "increases base fee when utilization > 50%" do
      result = EIP1559FeeCalculatorPrism.predict_next_base_fee(20.0, [0.8])
      assert result > 20.0
    end

    test "decreases base fee when utilization < 50%" do
      result = EIP1559FeeCalculatorPrism.predict_next_base_fee(20.0, [0.2])
      assert result < 20.0
    end

    test "keeps base fee stable at 50% utilization" do
      result = EIP1559FeeCalculatorPrism.predict_next_base_fee(20.0, [0.5])
      assert result == 20.0
    end

    test "handles empty ratios" do
      result = EIP1559FeeCalculatorPrism.predict_next_base_fee(20.0, nil)
      assert result == 20.0
    end
  end

  describe "predict_base_fee_from_ratio/2" do
    test "increases for high utilization" do
      result = EIP1559FeeCalculatorPrism.predict_base_fee_from_ratio(100.0, 1.0)
      # At 100% utilization, increase by max 12.5%
      assert result > 100.0
      assert result <= 113.0
    end

    test "decreases for low utilization" do
      result = EIP1559FeeCalculatorPrism.predict_base_fee_from_ratio(100.0, 0.0)
      # At 0% utilization, decrease by max 12.5%
      assert result < 100.0
      assert result >= 87.0
    end

    test "never goes below 1.0" do
      result = EIP1559FeeCalculatorPrism.predict_base_fee_from_ratio(1.0, 0.0)
      assert result >= 1.0
    end
  end

  describe "view/0" do
    test "returns prism struct with correct metadata" do
      prism = EIP1559FeeCalculatorPrism.view()

      assert prism.name == "EIP-1559 Fee Calculator"
      assert prism.description =~ "EIP-1559"
      assert prism.input_schema != nil
    end
  end
end

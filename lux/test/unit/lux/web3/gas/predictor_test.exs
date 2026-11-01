defmodule Lux.Web3.Gas.PredictorTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.Predictor

  describe "calculate_next_base_fee/3" do
    test "returns same base fee when target gas equals gas used" do
      gas_limit = 30_000_000
      target_gas = 15_000_000
      current_base_fee = 20_000_000_000

      assert Predictor.calculate_next_base_fee(current_base_fee, target_gas, gas_limit) ==
               current_base_fee
    end

    test "increases base fee by max 12.5% when block is 100% full" do
      gas_limit = 30_000_000
      gas_used = 30_000_000
      current_base_fee = 20_000_000_000

      next_fee = Predictor.calculate_next_base_fee(current_base_fee, gas_used, gas_limit)
      expected_max = round(current_base_fee * 1.125)

      assert next_fee == expected_max
    end

    test "decreases base fee by 12.5% when block is completely empty" do
      gas_limit = 30_000_000
      gas_used = 0
      current_base_fee = 20_000_000_000

      next_fee = Predictor.calculate_next_base_fee(current_base_fee, gas_used, gas_limit)
      expected_min = round(current_base_fee * 0.875)

      assert next_fee == expected_min
    end
  end

  describe "assess_congestion/2" do
    test "classifies congestion correctly based on gas utilization" do
      assert Predictor.assess_congestion(5_000_000, 30_000_000) == :low
      assert Predictor.assess_congestion(15_000_000, 30_000_000) == :medium
      assert Predictor.assess_congestion(25_000_000, 30_000_000) == :high
      assert Predictor.assess_congestion(29_000_000, 30_000_000) == :extreme
    end
  end

  describe "predict_fees/2" do
    test "generates accurate fee predictions across tiers" do
      history = [
        %{gas_used: 20_000_000, gas_limit: 30_000_000, base_fee: 25_000_000_000, tips: [1.2, 1.8, 2.5]}
      ]

      standard = Predictor.predict_fees(:standard, %{history: history})
      fast = Predictor.predict_fees(:fast, %{history: history})
      slow = Predictor.predict_fees(:slow, %{history: history})

      assert standard.max_fee_gwei > slow.max_fee_gwei
      assert fast.max_fee_gwei > standard.max_fee_gwei
      assert standard.estimated_wait_seconds < slow.estimated_wait_seconds
      assert is_integer(standard.max_fee_wei)
      assert is_integer(standard.max_priority_fee_wei)
    end
  end

  describe "calculate_base_fee_ema/2" do
    test "computes exponential moving average properly" do
      values = [10.0, 15.0, 20.0, 25.0]
      ema = Predictor.calculate_base_fee_ema(values, 0.5)
      assert is_float(ema)
      assert ema > 10.0 and ema < 25.0
    end
  end
end

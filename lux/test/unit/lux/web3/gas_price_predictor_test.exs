defmodule Lux.Web3.Gas.PricePredictorTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.PricePredictor

  describe "predict/1" do
    test "returns fee recommendations with all tiers" do
      Application.put_env(:lux, :gas_prediction_blocks, [
        %{"baseFeePerGas" => "0x5d21dba00"},
        %{"baseFeePerGas" => "0x5b9a8d400"},
        %{"baseFeePerGas" => "0x5c8e3a800"},
        %{"baseFeePerGas" => "0x5a1234000"},
        %{"baseFeePerGas" => "0x5e4567800"}
      ])

      assert {:ok, rec} = PricePredictor.predict(network: "mainnet")

      assert is_map(rec.slow)
      assert is_map(rec.standard)
      assert is_map(rec.fast)
      assert is_integer(rec.base_fee)
      assert rec.base_fee > 0
      assert is_integer(rec.suggested_tip)
      assert rec.suggested_tip > 0
      assert rec.timestamp != nil
    end

    test "returns error when no base fee data available" do
      Application.put_env(:lux, :gas_prediction_blocks, [%{"foo" => "bar"}])
      assert {:error, :no_base_fee_data} = PricePredictor.predict()
    end
  end

  describe "compute_recommendations/2" do
    test "computes slow, standard, and fast tiers correctly" do
      base_fees = [25_000_000_000, 30_000_000_000, 28_000_000_000]
      priority_fees = %{low: 1_000_000_000, medium: 1_500_000_000, high: 3_000_000_000}

      rec = PricePredictor.compute_recommendations(base_fees, priority_fees)

      assert rec.base_fee == 28_000_000_000
      assert rec.suggested_tip == 1_500_000_000
      assert rec.slow.max_fee_per_gas < rec.standard.max_fee_per_gas
      assert rec.standard.max_fee_per_gas < rec.fast.max_fee_per_gas
      assert rec.slow.max_priority_fee_per_gas < rec.standard.max_priority_fee_per_gas
      assert rec.standard.max_priority_fee_per_gas < rec.fast.max_priority_fee_per_gas
    end
  end

  describe "fetch_priority_fee_suggestions/1" do
    test "returns sensible default priority fees" do
      assert {:ok, fees} = PricePredictor.fetch_priority_fee_suggestions("mainnet")
      assert fees.low > 0
      assert fees.medium > fees.low
      assert fees.high > fees.medium
    end
  end
end

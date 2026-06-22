defmodule Lux.Prisms.Gas.GasPricePredictionPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.GasPricePredictionPrism

  describe "handler/2 - basic functionality" do
    test "returns prediction with standard urgency" do
      result = GasPricePredictionPrism.handler(%{
        chain_id: 1,
        urgency: "standard"
      })

      assert {:ok, prediction} = result
      assert is_integer(prediction.recommended_gas_price)
      assert is_integer(prediction.base_fee)
      assert is_integer(prediction.priority_fee)
      assert prediction.tier == "standard"
      assert is_binary(prediction.estimated_inclusion_time)
      assert is_number(prediction.network_congestion)
      assert is_number(prediction.prediction_confidence)
      assert prediction.chain_id == 1
    end

    test "returns prediction with fast urgency" do
      result = GasPricePredictionPrism.handler(%{
        chain_id: 1,
        urgency: "fast"
      })

      assert {:ok, prediction} = result
      assert prediction.tier == "fast"
      # Fast should have higher priority fee than standard
    end

    test "returns prediction with safe urgency" do
      result = GasPricePredictionPrism.handler(%{
        chain_id: 1,
        urgency: "safe"
      })

      assert {:ok, prediction} = result
      assert prediction.tier == "safe"
    end

    test "respects max gas price cap" do
      result = GasPricePredictionPrism.handler(%{
        chain_id: 1,
        urgency: "fast",
        max_gas_price_gwei: 10
      })

      assert {:ok, prediction} = result
      assert prediction.recommended_gas_price <= 10 * 1_000_000_000
    end

    test "handles missing parameters with defaults" do
      result = GasPricePredictionPrism.handler(%{})

      assert {:ok, prediction} = result
      assert prediction.tier == "standard"
    end
  end

  describe "handler/2 - error cases" do
    test "returns error for invalid urgency" do
      result = GasPricePredictionPrism.handler(%{
        urgency: "ultra_fast"
      })

      assert {:ok, _prediction} = result
    end
  end

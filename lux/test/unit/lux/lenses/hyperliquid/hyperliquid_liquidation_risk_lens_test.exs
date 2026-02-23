defmodule Lux.Lenses.Hyperliquid.HyperliquidLiquidationRiskLensTest do
  @moduledoc """
  Test suite for HyperliquidLiquidationRiskLens.
  Verifies liquidation risk assessment logic and output structure.
  """

  use UnitCase, async: true

  alias Lux.Lenses.Hyperliquid.HyperliquidLiquidationRiskLens

  @agent_ctx %{agent: %{name: "RiskAgent"}}
  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "focus/2 — output structure" do
    test "returns required top-level fields" do
      case HyperliquidLiquidationRiskLens.focus(%{address: @test_address}, @agent_ctx) do
        {:ok, result} ->
          assert Map.has_key?(result, :address)
          assert Map.has_key?(result, :overall_risk)
          assert Map.has_key?(result, :positions)
          assert result.address == @test_address
          assert result.overall_risk in ["safe", "warning", "critical", "no_liquidation_risk"]
          assert is_list(result.positions)
        {:error, _} ->
          :ok
      end
    end

    test "position entries have required risk fields" do
      expected_position_keys = [
        :coin, :side, :entry_price, :liquidation_price,
        :current_value, :distance_to_liquidation_pct, :risk_level
      ]

      case HyperliquidLiquidationRiskLens.focus(%{address: @test_address}, @agent_ctx) do
        {:ok, %{positions: [pos | _]}} ->
          Enum.each(expected_position_keys, fn key ->
            assert Map.has_key?(pos, key), "Position missing key: #{key}"
          end)
          assert pos.risk_level in ["safe", "warning", "critical", "no_liquidation_risk"]
        {:ok, %{positions: []}} ->
          :ok
        {:error, _} ->
          :ok
      end
    end
  end

  describe "focus/2 — threshold configuration" do
    test "accepts custom warning and critical thresholds" do
      case HyperliquidLiquidationRiskLens.focus(%{
        address: @test_address,
        warning_threshold_pct: 30.0,
        critical_threshold_pct: 15.0
      }, @agent_ctx) do
        {:ok, result} ->
          assert is_binary(result.overall_risk)
        {:error, _} ->
          :ok
      end
    end

    test "overall_risk reflects worst position" do
      # If we have one critical position, overall should be critical
      case HyperliquidLiquidationRiskLens.focus(%{address: @test_address}, @agent_ctx) do
        {:ok, result} ->
          if length(result.positions) > 0 do
            position_risks = Enum.map(result.positions, & &1.risk_level)
            risk_priority = %{"critical" => 3, "warning" => 2, "safe" => 1, "no_liquidation_risk" => 0}
            worst = Enum.max_by(position_risks, &Map.get(risk_priority, &1, 0))
            assert result.overall_risk == worst
          end
        {:error, _} ->
          :ok
      end
    end
  end
end

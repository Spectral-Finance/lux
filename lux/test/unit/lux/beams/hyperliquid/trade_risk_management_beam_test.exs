defmodule Lux.Beams.Hyperliquid.TradeRiskManagementBeamTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Beams.Hyperliquid.TradeRiskManagementBeam

  @safe_metrics %{
    "position_size_ratio" => 0.1,
    "leverage" => 2.0,
    "portfolio_concentration" => 0.2,
    "liquidation_risk" => 0.05
  }

  defp ctx_with(metrics) do
    %{steps: %{risk_assessment: %{result: metrics}}}
  end

  describe "SCENARIO_HAPPY_PATH (happy_path)" do
    test "accepts a trade that is within all risk thresholds" do
      assert TradeRiskManagementBeam.should_execute?(ctx_with(@safe_metrics)) == true
    end
  end

  describe "SCENARIO_BOUNDARY (null / empty / boundary)" do
    test "rejects when risk assessment result is nil" do
      ctx = %{steps: %{risk_assessment: %{result: nil}}}
      refute TradeRiskManagementBeam.should_execute?(ctx)
    end

    test "rejects when risk assessment step is missing" do
      ctx = %{steps: %{}}
      refute TradeRiskManagementBeam.should_execute?(ctx)
    end
  end

  describe "SCENARIO_BOUNDARY_LIMIT (grace threshold ticks)" do
    test "accepts metrics exactly at the upper boundary (half-open inclusive ticks)" do
      at_limit = %{
        "position_size_ratio" => 0.2,
        "leverage" => 5.0,
        "portfolio_concentration" => 0.4,
        "liquidation_risk" => 0.1
      }
      assert TradeRiskManagementBeam.should_execute?(ctx_with(at_limit)) == true
    end

    test "rejects metrics just above the upper boundary" do
      over_limit = %{
        "position_size_ratio" => 0.2000001,
        "leverage" => 5.0,
        "portfolio_concentration" => 0.4,
        "liquidation_risk" => 0.1
      }
      refute TradeRiskManagementBeam.should_execute?(ctx_with(over_limit))
    end

    test "accepts zero leverage (lower boundary)" do
      at_lower = %{
        "position_size_ratio" => 0.0,
        "leverage" => 0.0,
        "portfolio_concentration" => 0.0,
        "liquidation_risk" => 0.0
      }
      assert TradeRiskManagementBeam.should_execute?(ctx_with(at_lower)) == true
    end
  end

  describe "SCENARIO_NEGATIVE_FAILURE (negative)" do
    test "rejects excessive position size ratio" do
      bad = Map.put(@safe_metrics, "position_size_ratio", 0.5)
      refute TradeRiskManagementBeam.should_execute?(ctx_with(bad))
    end

    test "rejects excessive leverage" do
      bad = Map.put(@safe_metrics, "leverage", 10.0)
      refute TradeRiskManagementBeam.should_execute?(ctx_with(bad))
    end

    test "rejects excessive portfolio concentration" do
      bad = Map.put(@safe_metrics, "portfolio_concentration", 0.8)
      refute TradeRiskManagementBeam.should_execute?(ctx_with(bad))
    end

    test "rejects excessive liquidation risk" do
      bad = Map.put(@safe_metrics, "liquidation_risk", 0.5)
      refute TradeRiskManagementBeam.should_execute?(ctx_with(bad))
    end
  end

  describe "SCENARIO_CONCURRENCY_RACE (concurrency)" do
    test "risk decision is deterministic and side-effect free under concurrent calls" do
      metrics_list = Enum.map(1..20, fn _ -> @safe_metrics end)

      results =
        metrics_list
        |> Enum.map(fn metrics ->
          Task.async(fn -> TradeRiskManagementBeam.should_execute?(ctx_with(metrics)) end)
        end)
        |> Enum.map(&Task.await/1)

      assert Enum.all?(results, &(&1 == true))
    end

    test "concurrent mixed accept/reject decisions do not interfere with each other" do
      accepted = ctx_with(@safe_metrics)
      rejected = ctx_with(Map.put(@safe_metrics, "leverage", 99.0))

      decisions =
        [accepted, rejected, accepted, rejected]
        |> Enum.map(fn ctx ->
          Task.async(fn -> TradeRiskManagementBeam.should_execute?(ctx) end)
        end)
        |> Enum.map(&Task.await/1)

      assert decisions == [true, false, true, false]
    end
  end
end

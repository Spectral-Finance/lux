defmodule Lux.Beams.Hyperliquid.PerpetualTradingBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.Hyperliquid.PerpetualTradingBeam

  describe "schema and beam definition" do
    test "view/0 returns valid beam struct" do
      beam = PerpetualTradingBeam.view()
      assert beam.name == "Hyperliquid Autonomous Perpetual Trading"
      assert beam.input_schema.required == ["address", "trade"]
      assert beam.output_schema.required == ["status", "order_result"]
      assert beam.generate_execution_log == true
    end
  end

  describe "should_execute?/1" do
    test "approves execution when all risk parameters are within safe limits" do
      ctx = %{
        steps: %{
          risk_assessment: %{
            result: %{
              "position_size_ratio" => 0.10,
              "leverage" => 5.0,
              "portfolio_concentration" => 0.20,
              "liquidation_risk" => 0.05
            }
          }
        }
      }

      assert PerpetualTradingBeam.should_execute?(ctx) == true
    end

    test "rejects execution when leverage exceeds safety boundary" do
      ctx = %{
        steps: %{
          risk_assessment: %{
            result: %{
              "position_size_ratio" => 0.10,
              "leverage" => 15.0,
              "portfolio_concentration" => 0.20,
              "liquidation_risk" => 0.05
            }
          }
        }
      }

      assert PerpetualTradingBeam.should_execute?(ctx) == false
    end

    test "rejects execution when liquidation risk is excessive" do
      ctx = %{
        steps: %{
          risk_assessment: %{
            result: %{
              "position_size_ratio" => 0.10,
              "leverage" => 5.0,
              "portfolio_concentration" => 0.20,
              "liquidation_risk" => 0.25
            }
          }
        }
      }

      assert PerpetualTradingBeam.should_execute?(ctx) == false
    end

    test "rejects execution when position size ratio is too large" do
      ctx = %{
        steps: %{
          risk_assessment: %{
            result: %{
              "position_size_ratio" => 0.40,
              "leverage" => 2.0,
              "portfolio_concentration" => 0.30,
              "liquidation_risk" => 0.02
            }
          }
        }
      }

      assert PerpetualTradingBeam.should_execute?(ctx) == false
    end
  end
end

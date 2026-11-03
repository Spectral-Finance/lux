defmodule Lux.Beams.TradingView.TechnicalAnalysisBeamTest do
  use UnitCase, async: true

  alias Lux.Beams.TradingView.TechnicalAnalysisBeam

  @sample_closes [
    44.34,
    44.09,
    44.15,
    43.61,
    44.33,
    44.83,
    45.10,
    45.42,
    45.84,
    46.08,
    45.89,
    46.03,
    45.61,
    46.28,
    46.28,
    46.00,
    46.03,
    46.41,
    46.22,
    45.64,
    46.00,
    46.50,
    47.10,
    47.50,
    47.20
  ]

  describe "run/2" do
    test "executes full technical analysis sequence pipeline" do
      input = %{
        symbol: "BTCUSDT",
        prices: @sample_closes
      }

      {:ok, result, log} = TechnicalAnalysisBeam.run(input)

      assert is_map(result)
      assert log.status == :completed
      assert length(log.steps) == 3

      step_ids = Enum.map(log.steps, & &1.id)
      assert :indicators in step_ids
      assert :signals in step_ids
      assert :alerts in step_ids
    end
  end
end

defmodule Lux.TradingView.MultiTimeframeTest do
  use UnitCase, async: true

  alias Lux.TradingView.MultiTimeframe

  describe "calculate_consensus/1" do
    test "determines consensus across multiple timeframe signals" do
      signals = [
        %{timeframe: "15m", recommendation: :buy},
        %{timeframe: "1h", recommendation: :strong_buy},
        %{timeframe: "4h", recommendation: :buy},
        %{timeframe: "1d", recommendation: :neutral}
      ]

      result = MultiTimeframe.calculate_consensus(signals)

      assert result.overall_bias == :bullish
      assert result.bullish_count == 3
      assert result.consensus_pct == 75.0
    end
  end
end

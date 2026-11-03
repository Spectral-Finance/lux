defmodule Lux.TradingView.MultiTimeframeTest do
  use UnitCase, async: true

  alias Lux.TradingView.MultiTimeframe

  describe "calculate_consensus/1" do
    test "determines bullish consensus across aligned timeframes" do
      signals = [
        %{timeframe: "15m", recommendation: :buy},
        %{timeframe: "1h", recommendation: :strong_buy},
        %{timeframe: "4h", score: 45},
        %{timeframe: "1D", recommendation: :neutral}
      ]

      result = MultiTimeframe.calculate_consensus(signals)
      assert result.overall_bias == :bullish
      assert result.bullish_count == 3
      assert result.neutral_count == 1
      assert result.consensus_pct == 75.0
      assert length(result.timeframes_analyzed) == 4
    end

    test "determines bearish consensus when majority point down" do
      signals = [
        %{timeframe: "15m", signal: :sell},
        %{timeframe: "1h", recommendation: :strong_sell},
        %{timeframe: "4h", score: -50}
      ]

      result = MultiTimeframe.calculate_consensus(signals)
      assert result.overall_bias == :bearish
      assert result.bearish_count == 3
      assert result.consensus_pct == 100.0
    end

    test "handles conflicting signals returning neutral bias" do
      signals = [
        %{timeframe: "15m", recommendation: :buy},
        %{timeframe: "1h", recommendation: :sell}
      ]

      result = MultiTimeframe.calculate_consensus(signals)
      assert result.overall_bias == :neutral
      assert result.consensus_pct == 0.0
    end
  end
end

defmodule Lux.Prisms.TradingView.MultiTimeframePrism do
  @moduledoc """
  Calculates multi-timeframe consensus from various chart interval signals.
  """

  use Lux.Prism,
    name: "TradingView Multi-Timeframe Consensus",
    description: "Evaluates alignment of signals across 15m, 1h, 4h, and 1D timeframes",
    input_schema: %{
      type: :object,
      properties: %{
        timeframe_signals: %{type: :array, description: "List of signal objects per timeframe"}
      },
      required: ["timeframe_signals"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        overall_bias: %{type: :string},
        consensus_pct: %{type: :number},
        bullish_count: %{type: :integer},
        bearish_count: %{type: :integer}
      },
      required: ["overall_bias", "consensus_pct"]
    }

  alias Lux.TradingView.MultiTimeframe

  def handler(input, _ctx) do
    signals = Map.get(input, :timeframe_signals) || Map.get(input, "timeframe_signals", [])
    consensus = MultiTimeframe.calculate_consensus(signals)

    {:ok,
     %{
       overall_bias: to_string(consensus.overall_bias) |> String.upcase(),
       consensus_pct: consensus.consensus_pct,
       bullish_count: consensus.bullish_count,
       bearish_count: consensus.bearish_count
     }}
  end
end

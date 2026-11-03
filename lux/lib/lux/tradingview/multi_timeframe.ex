defmodule Lux.TradingView.MultiTimeframe do
  @moduledoc """
  Multi-timeframe consensus aggregator for TradingView chart resolutions:
  - Aggregates indicator biases across 15m, 1h, 4h, and 1D timeframes
  - Calculates consensus strength and overall trend direction
  """

  @doc """
  Computes consensus agreement across multiple timeframe signals.
  """
  @spec calculate_consensus(list(map())) :: %{
          overall_bias: :bullish | :bearish | :neutral,
          consensus_pct: float(),
          bullish_count: non_neg_integer(),
          bearish_count: non_neg_integer(),
          neutral_count: non_neg_integer()
        }
  def calculate_consensus(timeframe_signals) when is_list(timeframe_signals) and length(timeframe_signals) > 0 do
    bullish = Enum.count(timeframe_signals, fn s -> s[:recommendation] in [:buy, :strong_buy] end)
    bearish = Enum.count(timeframe_signals, fn s -> s[:recommendation] in [:sell, :strong_sell] end)
    neutral = Enum.count(timeframe_signals, fn s -> s[:recommendation] == :neutral end)
    total = length(timeframe_signals)

    {bias, count} =
      cond do
        bullish > bearish and bullish > neutral -> {:bullish, bullish}
        bearish > bullish and bearish > neutral -> {:bearish, bearish}
        true -> {:neutral, neutral}
      end

    consensus_pct = Float.round(count / total * 100.0, 2)

    %{
      overall_bias: bias,
      consensus_pct: consensus_pct,
      bullish_count: bullish,
      bearish_count: bearish,
      neutral_count: neutral
    }
  end

  def calculate_consensus(_) do
    %{overall_bias: :neutral, consensus_pct: 0.0, bullish_count: 0, bearish_count: 0, neutral_count: 0}
  end
end

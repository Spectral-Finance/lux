defmodule Lux.TradingView.MultiTimeframe do
  @moduledoc """
  Multi-timeframe consensus evaluator for TradingView market analysis:
  - Aggregates technical indicators and signals across multiple chart resolutions (15m, 1h, 4h, 1D)
  - Evaluates cross-timeframe alignment before trade entry or alert dispatch
  - Computes consensus conviction percentage and majority directional bias
  """

  @doc """
  Evaluates a list of timeframe signal maps.
  Each map can be `%{timeframe: "1h", signal: :buy}` or `%{timeframe: "1h", score: 45}`.
  """
  @spec calculate_consensus(list(map())) :: %{
          overall_bias: :bullish | :bearish | :neutral,
          consensus_pct: float(),
          bullish_count: non_neg_integer(),
          bearish_count: non_neg_integer(),
          neutral_count: non_neg_integer(),
          timeframes_analyzed: list(String.t())
        }
  def calculate_consensus(timeframe_signals)
      when is_list(timeframe_signals) and length(timeframe_signals) > 0 do
    votes =
      Enum.map(timeframe_signals, fn tf_map ->
        bias =
          cond do
            # When recommendation is given
            tf_map[:recommendation] in [:strong_buy, :buy, "BUY", "STRONG_BUY"] -> :bullish
            tf_map[:recommendation] in [:strong_sell, :sell, "SELL", "STRONG_SELL"] -> :bearish
            tf_map[:signal] in [:bullish, :buy, "BUY"] -> :bullish
            tf_map[:signal] in [:bearish, :sell, "SELL"] -> :bearish
            # When raw score is given
            is_number(tf_map[:score]) and tf_map[:score] > 10 -> :bullish
            is_number(tf_map[:score]) and tf_map[:score] < -10 -> :bearish
            true -> :neutral
          end

        tf = to_string(tf_map[:timeframe] || tf_map["timeframe"] || "unknown")
        {tf, bias}
      end)

    bullish_count = Enum.count(votes, fn {_, b} -> b == :bullish end)
    bearish_count = Enum.count(votes, fn {_, b} -> b == :bearish end)
    neutral_count = Enum.count(votes, fn {_, b} -> b == :neutral end)
    total = length(votes)

    overall_bias =
      cond do
        bullish_count > bearish_count and bullish_count >= neutral_count -> :bullish
        bearish_count > bullish_count and bearish_count >= neutral_count -> :bearish
        true -> :neutral
      end

    dominant_count =
      cond do
        bullish_count > bearish_count -> bullish_count
        bearish_count > bullish_count -> bearish_count
        true -> 0
      end

    consensus_pct = if total > 0, do: Float.round(dominant_count / total * 100.0, 2), else: 0.0

    %{
      overall_bias: overall_bias,
      consensus_pct: consensus_pct,
      bullish_count: bullish_count,
      bearish_count: bearish_count,
      neutral_count: neutral_count,
      timeframes_analyzed: Enum.map(votes, fn {tf, _} -> tf end)
    }
  end

  def calculate_consensus(_) do
    %{
      overall_bias: :neutral,
      consensus_pct: 0.0,
      bullish_count: 0,
      bearish_count: 0,
      neutral_count: 0,
      timeframes_analyzed: []
    }
  end
end

defmodule Lux.TradingView.Signals do
  @moduledoc """
  Technical analysis signal aggregator and market sentiment classifier:
  - Aggregates RSI, MACD, and Bollinger Bands confluence
  - Scores market bias from -100 (Strong Sell) to +100 (Strong Buy)
  - Identifies overbought/oversold and trend reversal setups
  """

  @type recommendation :: :strong_buy | :buy | :neutral | :sell | :strong_sell

  @doc """
  Evaluates indicator signals and computes composite bias score.
  """
  @spec generate_signal(float(), float() | nil, map() | nil, map() | nil) :: %{
          score: integer(),
          recommendation: recommendation(),
          rsi_signal: :oversold | :overbought | :neutral,
          macd_signal: :bullish | :bearish | :neutral,
          bb_signal: :bounce_buy | :rejection_sell | :neutral
        }
  def generate_signal(current_price, rsi, macd, bollinger_bands) do
    # 1. RSI Score (-30 to +30)
    {rsi_score, rsi_signal} =
      cond do
        is_nil(rsi) -> {0, :neutral}
        rsi <= 30.0 -> {+30, :oversold}
        rsi >= 70.0 -> {-30, :overbought}
        rsi <= 45.0 -> {+10, :neutral}
        rsi >= 55.0 -> {-10, :neutral}
        true -> {0, :neutral}
      end

    # 2. MACD Score (-40 to +40)
    {macd_score, macd_signal} =
      cond do
        is_nil(macd) -> {0, :neutral}
        macd.histogram > 0.0 and macd.macd_line > 0.0 -> {+40, :bullish}
        macd.histogram > 0.0 -> {+20, :bullish}
        macd.histogram < 0.0 and macd.macd_line < 0.0 -> {-40, :bearish}
        macd.histogram < 0.0 -> {-20, :bearish}
        true -> {0, :neutral}
      end

    # 3. Bollinger Bands Score (-30 to +30)
    {bb_score, bb_signal} =
      cond do
        is_nil(bollinger_bands) -> {0, :neutral}
        current_price <= bollinger_bands.lower_band -> {+30, :bounce_buy}
        current_price >= bollinger_bands.upper_band -> {-30, :rejection_sell}
        true -> {0, :neutral}
      end

    total_score = rsi_score + macd_score + bb_score

    recommendation =
      cond do
        total_score >= 60 -> :strong_buy
        total_score >= 20 -> :buy
        total_score <= -60 -> :strong_sell
        total_score <= -20 -> :sell
        true -> :neutral
      end

    %{
      score: total_score,
      recommendation: recommendation,
      rsi_signal: rsi_signal,
      macd_signal: macd_signal,
      bb_signal: bb_signal
    }
  end
end

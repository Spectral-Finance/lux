defmodule Lux.TradingView.Signals do
  @moduledoc """
  Multi-indicator confluence signal generator and scoring engine for TradingView technical analysis:
  - Aggregates Momentum (RSI, Stochastic), Trend (MACD, Moving Averages), and Volatility (Bollinger Bands)
  - Produces a composite bias score between -100 (Maximum Bearish) and +100 (Maximum Bullish)
  - Emits normalized trade recommendations: `:strong_buy`, `:buy`, `:neutral`, `:sell`, `:strong_sell`
  """

  alias Lux.TradingView.Indicators

  @type recommendation :: :strong_buy | :buy | :neutral | :sell | :strong_sell

  @doc """
  Generates consolidated signal analysis and score from market indicators,
  a candlestick list, or a market snapshot map.
  """
  def generate_signal(candles_or_snapshot, opts \\ [])

  def generate_signal(candles, _opts) when is_list(candles) do
    {:ok, analysis} = Indicators.calculate_all(candles)
    current_price = analysis[:current_price] || 0.0

    generate_signal(
      current_price,
      analysis[:rsi],
      analysis[:macd],
      analysis[:bollinger],
      analysis[:stochastic]
    )
  end

  def generate_signal(%{} = snapshot, _opts) do
    current_price =
      snapshot[:current_price] || snapshot["current_price"] || snapshot[:close] ||
        snapshot["close"] || 0.0

    rsi = snapshot[:rsi] || snapshot["rsi"]
    macd = snapshot[:macd] || snapshot["macd"]

    bb =
      snapshot[:bollinger_bands] || snapshot["bollinger_bands"] || snapshot[:bollinger] ||
        snapshot["bollinger"]

    stoch = snapshot[:stochastic] || snapshot["stochastic"]
    generate_signal(current_price, rsi, macd, bb, stoch)
  end

  def generate_signal(current_price, rsi) when is_number(current_price) do
    generate_signal(current_price, rsi, nil, nil, nil)
  end

  @doc """
  Generates consolidated signal analysis and score from market indicators.
  """
  @spec generate_signal(number(), float() | nil, map() | nil, map() | nil, map() | nil) :: %{
          score: integer(),
          recommendation: recommendation(),
          rsi_signal: :bullish | :bearish | :neutral,
          macd_signal: :bullish | :bearish | :neutral,
          bb_signal: :bullish | :bearish | :neutral,
          stoch_signal: :bullish | :bearish | :neutral,
          indicators_evaluated: pos_integer()
        }
  def generate_signal(current_price, rsi, macd, bb, stoch) do
    current_price = to_num(current_price)

    # 1. RSI Score (-30 to +30)
    {rsi_score, rsi_sig} =
      case rsi do
        val when is_number(val) and val <= 30.0 ->
          {+30, :bullish}

        val when is_number(val) and val >= 70.0 ->
          {-30, :bearish}

        val when is_number(val) and val > 50.0 ->
          {+10, :bullish}

        val when is_number(val) and val < 50.0 ->
          {-10, :bearish}

        _ ->
          {0, :neutral}
      end

    # 2. MACD Score (-35 to +35)
    {macd_score, macd_sig} =
      case macd do
        %{histogram: h, trend: :bullish} when h > 0.0 ->
          {+35, :bullish}

        %{histogram: h, trend: :bearish} when h < 0.0 ->
          {-35, :bearish}

        %{trend: :bullish} ->
          {+20, :bullish}

        %{trend: :bearish} ->
          {-20, :bearish}

        _ ->
          {0, :neutral}
      end

    # 3. Bollinger Bands Score (-25 to +25)
    {bb_score, bb_sig} =
      case bb do
        %{upper: u, lower: l} when current_price > 0.0 ->
          cond do
            current_price <= l ->
              {+25, :bullish}

            current_price >= u ->
              {-25, :bearish}

            true ->
              {0, :neutral}
          end

        _ ->
          {0, :neutral}
      end

    # 4. Stochastic Score (-15 to +15)
    {stoch_score, stoch_sig} =
      case stoch do
        %{k: k} when is_number(k) and k <= 20.0 ->
          {+15, :bullish}

        %{k: k} when is_number(k) and k >= 80.0 ->
          {-15, :bearish}

        _ ->
          {0, :neutral}
      end

    # Composite sum bounded between -100 and +100
    raw_score = rsi_score + macd_score + bb_score + stoch_score
    clamped_score = max(-100, min(100, raw_score))

    recommendation =
      cond do
        clamped_score >= 60 -> :strong_buy
        clamped_score >= 20 -> :buy
        clamped_score <= -60 -> :strong_sell
        clamped_score <= -20 -> :sell
        true -> :neutral
      end

    %{
      score: clamped_score,
      recommendation: recommendation,
      rsi_signal: rsi_sig,
      macd_signal: macd_sig,
      bb_signal: bb_sig,
      stoch_signal: stoch_sig,
      indicators_evaluated: 4
    }
  end

  defp to_num(v) when is_number(v), do: v * 1.0
  defp to_num(_), do: 0.0
end

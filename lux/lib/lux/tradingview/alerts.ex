defmodule Lux.TradingView.Alerts do
  @moduledoc """
  Alert lifecycle manager and trigger evaluation engine for TradingView technical indicators:
  - Manages chart alert rules (price threshold, RSI overbought/oversold, Bollinger breakout, MACD cross, custom PineScript)
  - Evaluates live trigger conditions against market snapshots
  - Enforces trigger cooldowns and maintains alert trigger history
  """

  alias Lux.TradingView.PineScript

  @type alert_rule :: %{
          id: String.t(),
          symbol: String.t(),
          condition: atom() | String.t(),
          threshold: number() | nil,
          script: String.t() | nil,
          cooldown_sec: pos_integer(),
          last_triggered: integer() | nil
        }

  @doc """
  Evaluates a list of alert rules against the latest market data snapshot.
  Returns `{:ok, %{triggered_alerts: list(), active_count: integer()}}`.
  """
  @spec evaluate_alerts(list(alert_rule() | map()), map()) ::
          {:ok, %{triggered_alerts: list(map()), active_count: integer()}}
  def evaluate_alerts(rules, snapshot) when is_list(rules) and is_map(snapshot) do
    now = System.system_time(:second)

    price =
      to_num(
        snapshot[:current_price] || snapshot["current_price"] || snapshot[:close] ||
          snapshot["close"]
      )

    rsi = snapshot[:rsi] || snapshot["rsi"]
    bb = snapshot[:bollinger_bands] || snapshot["bollinger_bands"]
    macd = snapshot[:macd] || snapshot["macd"]

    triggered =
      rules
      |> Enum.filter(&active_rule?(&1, now))
      |> Enum.reduce([], fn rule, acc ->
        case check_rule(rule, snapshot, price, rsi, bb, macd) do
          {:triggered, reason} ->
            event = %{
              rule_id: rule[:id] || rule["id"] || "alert",
              symbol: rule[:symbol] || rule["symbol"] || snapshot[:symbol] || "UNKNOWN",
              condition: rule[:condition] || rule["condition"],
              reason: reason,
              timestamp: now,
              price: price
            }

            [event | acc]

          :no_trigger ->
            acc
        end
      end)
      |> Enum.reverse()

    {:ok,
     %{
       triggered_alerts: triggered,
       active_count: length(triggered)
     }}
  end

  defp active_rule?(rule, now) do
    cooldown = rule[:cooldown_sec] || rule["cooldown_sec"] || 60
    last_t = rule[:last_triggered] || rule["last_triggered"]

    case last_t do
      nil -> true
      t when is_integer(t) -> now - t >= cooldown
      _ -> true
    end
  end

  defp check_rule(rule, snapshot, price, rsi, bb, macd) do
    cond_type = rule[:condition] || rule["condition"]
    threshold = to_num(rule[:threshold] || rule["threshold"])

    case cond_type do
      :price_above ->
        if price >= threshold and threshold > 0,
          do: {:triggered, "Price #{price} crossed above threshold #{threshold}"},
          else: :no_trigger

      :price_below ->
        if price <= threshold and threshold > 0,
          do: {:triggered, "Price #{price} crossed below threshold #{threshold}"},
          else: :no_trigger

      :rsi_overbought ->
        r_thresh = if threshold > 0, do: threshold, else: 70.0

        if rsi && rsi >= r_thresh,
          do: {:triggered, "RSI #{rsi} reached overbought level #{r_thresh}"},
          else: :no_trigger

      :rsi_oversold ->
        r_thresh = if threshold > 0, do: threshold, else: 30.0

        if rsi && rsi <= r_thresh,
          do: {:triggered, "RSI #{rsi} reached oversold level #{r_thresh}"},
          else: :no_trigger

      :bb_breakout_upper ->
        upper = bb && (bb[:upper] || bb["upper"])

        if upper && price >= upper,
          do: {:triggered, "Price #{price} broke above upper Bollinger Band #{upper}"},
          else: :no_trigger

      :bb_breakout_lower ->
        lower = bb && (bb[:lower] || bb["lower"])

        if lower && price <= lower,
          do: {:triggered, "Price #{price} broke below lower Bollinger Band #{lower}"},
          else: :no_trigger

      :macd_bullish_cross ->
        hist = macd && (macd[:histogram] || macd["histogram"])

        if hist && hist > 0.0,
          do: {:triggered, "MACD histogram flipped bullish (+#{hist})"},
          else: :no_trigger

      :macd_bearish_cross ->
        hist = macd && (macd[:histogram] || macd["histogram"])

        if hist && hist < 0.0,
          do: {:triggered, "MACD histogram flipped bearish (#{hist})"},
          else: :no_trigger

      :custom_pinescript ->
        script = rule[:script] || rule["script"] || ""

        case PineScript.execute(script, snapshot) do
          {:ok, %{triggered?: true}} ->
            {:triggered, "Custom Pine Script condition evaluated to true: #{script}"}

          _ ->
            :no_trigger
        end

      _ ->
        :no_trigger
    end
  end

  defp to_num(v) when is_number(v), do: v * 1.0

  defp to_num(v) when is_binary(v) do
    case Float.parse(v) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_num(_), do: 0.0
end

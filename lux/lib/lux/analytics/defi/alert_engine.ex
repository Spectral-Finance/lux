defmodule Lux.Analytics.Defi.AlertEngine do
  @moduledoc """
  Anomaly detection and threshold alert engine for DeFi protocols:
  - TVL shocks and drawdown detection
  - Yield pool APY spikes and collapses
  - Stablecoin peg deviation warnings
  """

  @type alert :: %{
          id: String.t(),
          type: :tvl_shock | :yield_anomaly | :depeg_risk,
          severity: :info | :warning | :critical,
          protocol: String.t(),
          message: String.t(),
          metric_value: float(),
          threshold: float()
        }

  @doc """
  Checks protocol TVL 24h change against drawdown thresholds.
  """
  @spec check_tvl_drawdown(String.t(), float(), float()) :: {:ok, alert()} | :no_alert
  def check_tvl_drawdown(protocol, change_1d_pct, threshold_pct \\ -10.0) do
    if change_1d_pct <= threshold_pct do
      severity = if change_1d_pct <= -25.0, do: :critical, else: :warning

      alert = %{
        id: "alt_tvl_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)),
        type: :tvl_shock,
        severity: severity,
        protocol: protocol,
        message: "Protocol #{protocol} suffered a #{change_1d_pct}% TVL drawdown in 24 hours (threshold: #{threshold_pct}%)",
        metric_value: change_1d_pct,
        threshold: threshold_pct
      }

      {:ok, alert}
    else
      :no_alert
    end
  end

  @doc """
  Checks stablecoin price for depeg divergence from target $1.00 peg.
  """
  @spec check_depeg(String.t(), float(), float()) :: {:ok, alert()} | :no_alert
  def check_depeg(symbol, current_price, tolerance_pct \\ 1.0) do
    deviation_pct = abs(current_price - 1.0) * 100.0

    if deviation_pct >= tolerance_pct do
      severity = if deviation_pct >= 5.0, do: :critical, else: :warning

      alert = %{
        id: "alt_peg_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)),
        type: :depeg_risk,
        severity: severity,
        protocol: symbol,
        message: "Stablecoin #{symbol} is depegged by #{Float.round(deviation_pct, 2)}% at $#{current_price}",
        metric_value: Float.round(deviation_pct, 2),
        threshold: tolerance_pct
      }

      {:ok, alert}
    else
      :no_alert
    end
  end

  @doc """
  Checks yield pool for abnormal APY spikes or collapses.
  """
  @spec check_yield_anomaly(String.t(), float(), float(), float()) :: {:ok, alert()} | :no_alert
  def check_yield_anomaly(pool_name, apy_pct, max_threshold \\ 200.0, min_threshold \\ 0.0) do
    cond do
      apy_pct >= max_threshold ->
        alert = %{
          id: "alt_yld_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)),
          type: :yield_anomaly,
          severity: :warning,
          protocol: pool_name,
          message: "Pool #{pool_name} exhibits abnormal yield spike of #{apy_pct}% APY",
          metric_value: apy_pct,
          threshold: max_threshold
        }

        {:ok, alert}

      apy_pct <= min_threshold ->
        alert = %{
          id: "alt_yld_" <> (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)),
          type: :yield_anomaly,
          severity: :info,
          protocol: pool_name,
          message: "Pool #{pool_name} yield dropped to #{apy_pct}% APY",
          metric_value: apy_pct,
          threshold: min_threshold
        }

        {:ok, alert}

      true ->
        :no_alert
    end
  end
end

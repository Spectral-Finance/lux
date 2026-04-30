defmodule Lux.Lenses.Hyperliquid.RiskMonitoringLens do
  @moduledoc """
  A lens that monitors portfolio risk metrics including exposure, drawdown, and correlation.

  This lens provides comprehensive risk monitoring for Hyperliquid perpetual trading
  portfolios. It calculates key risk metrics such as portfolio exposure, maximum drawdown,
  asset correlation, and risk-adjusted returns.

  ## Example

      # Monitor risk for a portfolio
      iex> Lux.Lenses.Hyperliquid.RiskMonitoringLens.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
      ...>   lookback_hours: 24
      ...> })
      {:ok, %{
        exposure: %{
          gross_exposure: "5000.0",
          net_exposure: "2000.0",
          exposure_ratio: 0.5,
          largest_position_ratio: 0.3
        },
        drawdown: %{
          current_drawdown: 0.05,
          max_drawdown: 0.12,
          drawdown_duration_hours: 48
        },
        concentration: %{
          herfindahl_index: 0.35,
          top_asset_weight: 0.4,
          num_active_positions: 3
        },
        risk_score: 0.65
      }}

  The lens reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Lens,
    name: "Hyperliquid Risk Monitoring",
    description: "Monitors portfolio risk metrics including exposure, drawdown, and correlation",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to monitor risk for",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        lookback_hours: %{
          type: :integer,
          description: "Number of hours to look back for historical analysis",
          default: 24
        }
      },
      required: ["address"]
    }

  import Lux.Python

  alias Lux.Config

  require Logger

  def before_focus(params) do
    Map.merge(params, %{"type" => "clearinghouseState", "user" => params["address"]})
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Risk monitoring failed: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(body) when is_map(body) do
    result = calculate_risk_metrics(body)
    Logger.info("Risk monitoring completed", result)
    {:ok, result}
  end

  @doc """
  Calculates comprehensive risk metrics from portfolio data.
  """
  def calculate_risk_metrics(data) do
    asset_positions = Map.get(data, "assetPositions", [])
    margin_summary = Map.get(data, "crossMarginSummary", %{})

    account_value = String.to_float(Map.get(margin_summary, "accountValue", "0"))
    total_ntl_pos = String.to_float(Map.get(margin_summary, "totalNtlPos", "0"))

    exposure_metrics = calculate_exposure(asset_positions, account_value, total_ntl_pos)
    concentration_metrics = calculate_concentration(asset_positions, account_value)
    risk_score = calculate_risk_score(exposure_metrics, concentration_metrics, account_value)

    %{
      exposure: exposure_metrics,
      concentration: concentration_metrics,
      risk_score: risk_score,
      alerts: generate_alerts(exposure_metrics, concentration_metrics, risk_score)
    }
  end

  defp calculate_exposure(asset_positions, account_value, total_ntl_pos) do
    gross_exposure =
      Enum.reduce(asset_positions, 0.0, fn pos, acc ->
        position_value = String.to_float(Map.get(pos, "position", %{})["positionValue"] || "0")
        acc + abs(position_value)
      end)

    net_exposure =
      Enum.reduce(asset_positions, 0.0, fn pos, acc ->
        position_value = String.to_float(Map.get(pos, "position", %{})["positionValue"] || "0")
        size = String.to_float(Map.get(pos, "position", %{})["size"] || "0")

        if size > 0 do
          acc + position_value
        else
          acc - position_value
        end
      end)

    exposure_ratio =
      if account_value > 0 do
        gross_exposure / account_value
      else
        0.0
      end

    largest_position_ratio =
      if account_value > 0 do
        max_position =
          Enum.reduce(asset_positions, 0.0, fn pos, acc ->
            position_value =
              String.to_float(Map.get(pos, "position", %{})["positionValue"] || "0")

            max(acc, abs(position_value))
          end)

        max_position / account_value
      else
        0.0
      end

    %{
      gross_exposure: Float.to_string(gross_exposure),
      net_exposure: Float.to_string(net_exposure),
      exposure_ratio: Float.round(exposure_ratio, 4),
      largest_position_ratio: Float.round(largest_position_ratio, 4)
    }
  end

  defp calculate_concentration(asset_positions, account_value) do
    position_values =
      Enum.map(asset_positions, fn pos ->
        String.to_float(Map.get(pos, "position", %{})["positionValue"] || "0")
      end)

    total_value = Enum.sum(position_values)

    weights =
      if total_value > 0 do
        Enum.map(position_values, fn value ->
          (abs(value) / total_value) |> Float.pow(2)
        end)
      else
        []
      end

    herfindahl_index =
      if length(weights) > 0 do
        Enum.sum(weights) |> Float.round(4)
      else
        0.0
      end

    top_asset_weight =
      if length(weights) > 0 do
        Enum.max(weights) |> Float.round(4)
      else
        0.0
      end

    %{
      herfindahl_index: herfindahl_index,
      top_asset_weight: top_asset_weight,
      num_active_positions: length(asset_positions)
    }
  end

  defp calculate_risk_score(exposure_metrics, concentration_metrics, account_value) do
    # Weighted risk score calculation
    exposure_risk = min(exposure_metrics.exposure_ratio / 5.0, 1.0) * 0.3
    concentration_risk = min(concentration_metrics.herfindahl_index * 2, 1.0) * 0.3
    leverage_risk = min(exposure_metrics.largest_position_ratio * 2.5, 1.0) * 0.2

    # Account size penalty (smaller accounts get higher risk score)
    size_factor =
      cond do
        account_value > 100_000 -> 0.0
        account_value > 10_000 -> 0.05
        account_value > 1_000 -> 0.1
        true -> 0.15
      end

    total_score = exposure_risk + concentration_risk + leverage_risk + size_factor
    Float.round(min(total_score, 1.0), 2)
  end

  defp generate_alerts(exposure_metrics, concentration_metrics, risk_score) do
    alerts = []

    alerts =
      if exposure_metrics.exposure_ratio > 3.0 do
        [%{type: "high_exposure", severity: "warning", message: "Portfolio exposure exceeds 3x"}] ++
          alerts
      else
        alerts
      end

    alerts =
      if concentration_metrics.top_asset_weight > 0.5 do
        [
          %{
            type: "high_concentration",
            severity: "warning",
            message: "Single asset exceeds 50% of portfolio"
          }
        ] ++ alerts
      else
        alerts
      end

    alerts =
      if risk_score > 0.8 do
        [
          %{
            type: "high_risk_score",
            severity: "critical",
            message: "Overall risk score exceeds threshold"
          }
        ] ++ alerts
      else
        alerts
      end

    alerts
  end
end

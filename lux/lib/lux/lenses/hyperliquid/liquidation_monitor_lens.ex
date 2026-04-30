defmodule Lux.Lenses.Hyperliquid.LiquidationMonitorLens do
  @moduledoc """
  A lens that monitors liquidation prices and margin health for Hyperliquid positions.

  This lens provides real-time monitoring of liquidation risk across all open positions.
  It calculates distance to liquidation, margin health ratios, and provides early warning
  alerts when positions approach dangerous levels.

  ## Example

      # Monitor liquidation risk
      iex> Lux.Lenses.Hyperliquid.LiquidationMonitorLens.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> })
      {:ok, %{
        positions: [
          %{
            coin: "ETH",
            current_price: "2950.0",
            liquidation_price: "1400.0",
            distance_to_liquidation: 0.525,
            margin_health: 0.85,
            maintenance_margin: "500.0",
            warning_level: "safe"
          }
        ],
        summary: %{
          total_positions_at_risk: 0,
          average_distance_to_liquidation: 0.525,
          overall_margin_health: 0.85
        }
      }}

  The lens reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  - :hyperliquid_address - (Optional) Ethereum account address
  """

  use Lux.Lens,
    name: "Hyperliquid Liquidation Monitor",
    description: "Monitors liquidation prices and margin health for positions",
    url: "https://api.hyperliquid.xyz/info",
    method: :post,
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Ethereum address to monitor for liquidation risk",
          pattern: "^0x[a-fA-F0-9]{40}$"
        }
      },
      required: ["address"]
    }

  import Lux.Python

  alias Lux.Config

  require Logger

  # Warning thresholds
  @danger_threshold 0.15
  @warning_threshold 0.25
  @caution_threshold 0.40

  def before_focus(params) do
    Map.merge(params, %{"type" => "clearinghouseState", "user" => params["address"]})
  end

  def after_focus(%{"error" => error}) do
    Logger.error("Liquidation monitoring failed: #{inspect(error)}")
    {:error, error}
  end

  def after_focus(body) when is_map(body) do
    result = monitor_liquidation_risk(body)
    Logger.info("Liquidation monitoring completed", result)
    {:ok, result}
  end

  @doc """
  Monitors liquidation risk for all positions in the portfolio.
  """
  def monitor_liquidation_risk(data) do
    asset_positions = Map.get(data, "assetPositions", [])
    margin_summary = Map.get(data, "crossMarginSummary", %{})

    account_value = String.to_float(Map.get(margin_summary, "accountValue", "0"))
    total_margin_used = String.to_float(Map.get(margin_summary, "totalMarginUsed", "0"))

    position_monitoring =
      Enum.map(asset_positions, fn pos ->
        monitor_position(pos)
      end)

    positions_at_risk =
      Enum.count(position_monitoring, fn pm ->
        pm.warning_level in ["danger", "warning"]
      end)

    avg_distance =
      case position_monitoring do
        [] -> 0.0
        positions ->
          total_distance = Enum.sum(Enum.map(positions, & &1.distance_to_liquidation))
          total_distance / length(positions)
      end

    overall_margin_health =
      if account_value > 0 do
        Float.round((account_value - total_margin_used) / account_value, 4)
      else
        0.0
      end

    %{
      positions: position_monitoring,
      summary: %{
        total_positions_at_risk: positions_at_risk,
        average_distance_to_liquidation: Float.round(avg_distance, 4),
        overall_margin_health: overall_margin_health,
        account_value: Float.to_string(account_value),
        total_margin_used: Float.to_string(total_margin_used)
      },
      alerts: generate_liquidation_alerts(position_monitoring, positions_at_risk)
    }
  end

  defp monitor_position(pos) do
    position_data = Map.get(pos, "position", %{})
    coin = Map.get(position_data, "coin", "")
    size = String.to_float(Map.get(position_data, "size", "0"))
    entry_px = String.to_float(Map.get(position_data, "entryPx", "0"))
    liq_px_string = Map.get(position_data, "liquidationPx", "nil")
    margin_used = String.to_float(Map.get(position_data, "marginUsed", "0"))
    position_value = String.to_float(Map.get(position_data, "positionValue", "0"))

    # Calculate current mark price from position data
    current_price =
      if entry_px > 0 and size != 0 do
        # Derive mark price from position value and size
        abs(position_value / size)
      else
        0.0
      end

    liq_px =
      case liq_px_string do
        "nil" -> 0.0
        nil -> 0.0
        px -> String.to_float(px)
      end

    distance_to_liquidation =
      if liq_px > 0 and current_price > 0 do
        if size > 0 do
          # Long position
          (current_price - liq_px) / current_price
        else
          # Short position
          (liq_px - current_price) / current_price
        end
      else
        1.0
      end

    margin_health =
      if position_value > 0 do
        Float.round(margin_used / position_value, 4)
      else
        0.0
      end

    warning_level = determine_warning_level(distance_to_liquidation)

    %{
      coin: coin,
      current_price: Float.to_string(current_price),
      liquidation_price: Float.to_string(liq_px),
      distance_to_liquidation: Float.round(distance_to_liquidation, 4),
      margin_health: margin_health,
      maintenance_margin: Float.to_string(margin_used),
      warning_level: warning_level,
      size: Float.to_string(size),
      entry_price: Float.to_string(entry_px)
    }
  end

  defp determine_warning_level(distance) do
    cond do
      distance <= @danger_threshold -> "danger"
      distance <= @warning_threshold -> "warning"
      distance <= @caution_threshold -> "caution"
      true -> "safe"
    end
  end

  defp generate_liquidation_alerts(position_monitoring, positions_at_risk) do
    alerts = []

    # Alert for positions in danger
    danger_positions =
      Enum.filter(position_monitoring, fn pm -> pm.warning_level == "danger" end)

    alerts =
      Enum.reduce(danger_positions, alerts, fn pm, acc ->
        [
          %{
            type: "liquidation_danger",
            severity: "critical",
            coin: pm.coin,
            message: "Position #{pm.coin} is at risk of liquidation (#{Float.to_string(pm.distance_to_liquidation * 100)}% distance)"
          }
        ] ++ acc
      end)

    # Alert for multiple positions at risk
    alerts =
      if positions_at_risk > 2 do
        [
          %{
            type: "multiple_positions_at_risk",
            severity: "warning",
            message: "#{positions_at_risk} positions are at risk"
          }
        ] ++ alerts
      else
        alerts
      end

    alerts
  end
end

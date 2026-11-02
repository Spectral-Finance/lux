defmodule Lux.Trading.Hyperliquid.LiquidationProtector do
  @moduledoc """
  Liquidation risk monitoring and automated de-risking for Hyperliquid perpetual positions:
  - Computes exact liquidation price and buffer distance percentage
  - Multi-tier alert thresholds (Safe, Moderate, Warning, Critical)
  - Recommends protective actions (margin injection, partial size reduction, emergency close)
  """

  @doc """
  Calculates distance to liquidation as a percentage of current mark price.
  """
  @spec liquidation_distance_pct(float(), float()) :: float()
  def liquidation_distance_pct(mark_px, liq_px) when mark_px > 0 and liq_px > 0 do
    dist = abs(mark_px - liq_px) / mark_px * 100.0
    Float.round(dist, 2)
  end

  def liquidation_distance_pct(_, _), do: 0.0

  @doc """
  Evaluates liquidation risk tier for a position.
  """
  @spec evaluate_risk_tier(map()) :: %{
          distance_pct: float(),
          tier: :safe | :moderate | :warning | :critical,
          action: :none | :monitor | :partial_close | :emergency_close,
          alert: String.t() | nil
        }
  def evaluate_risk_tier(position) when is_map(position) do
    mark_px = Map.get(position, :mark_px, 0.0)
    liq_px = Map.get(position, :liquidation_px, 0.0)
    coin = Map.get(position, :coin, "ETH")

    dist = liquidation_distance_pct(mark_px, liq_px)

    cond do
      dist >= 15.0 ->
        %{
          distance_pct: dist,
          tier: :safe,
          action: :none,
          alert: nil
        }

      dist >= 8.0 ->
        %{
          distance_pct: dist,
          tier: :moderate,
          action: :monitor,
          alert: "Position #{coin} is #{dist}% away from liquidation"
        }

      dist >= 4.0 ->
        %{
          distance_pct: dist,
          tier: :warning,
          action: :partial_close,
          alert: "WARNING: Position #{coin} is only #{dist}% from liquidation. Partial reduction recommended."
        }

      true ->
        %{
          distance_pct: dist,
          tier: :critical,
          action: :emergency_close,
          alert: "CRITICAL ALERT: Position #{coin} is #{dist}% from liquidation! Immediate de-risking required."
        }
    end
  end

  @doc """
  Plans an automated de-risking action for a position facing liquidation risk.
  """
  @spec plan_derisk(map()) :: %{
          derisk_required?: boolean(),
          action: atom(),
          close_size: float(),
          reason: String.t()
        }
  def plan_derisk(position) when is_map(position) do
    risk = evaluate_risk_tier(position)
    sz = Map.get(position, :sz, 0.0)

    case risk.action do
      :emergency_close ->
        %{
          derisk_required?: true,
          action: :market_close,
          close_size: sz,
          reason: risk.alert
        }

      :partial_close ->
        %{
          derisk_required?: true,
          action: :partial_close_50pct,
          close_size: Float.round(sz * 0.5, 4),
          reason: risk.alert
        }

      _ ->
        %{
          derisk_required?: false,
          action: :hold,
          close_size: 0.0,
          reason: "Position is within acceptable risk parameters"
        }
    end
  end
end

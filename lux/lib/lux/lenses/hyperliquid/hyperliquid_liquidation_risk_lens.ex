defmodule Lux.Lenses.Hyperliquid.HyperliquidLiquidationRiskLens do
  @moduledoc """
  A lens for monitoring liquidation risk across open Hyperliquid positions.

  Calculates the distance to liquidation for each open position and provides
  a risk score to help agents take protective action before liquidation occurs.

  Risk levels:
  - `safe` — More than 20% price move needed to liquidate
  - `warning` — 10–20% price move triggers liquidation
  - `critical` — Less than 10% price move triggers liquidation
  - `no_position` — No open position for this coin

  ## Example

      iex> HyperliquidLiquidationRiskLens.focus(%{
      ...>   address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5"
      ...> }, %{agent: %{name: "RiskAgent"}})
      {:ok, %{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
        overall_risk: "safe",
        positions: [
          %{
            coin: "ETH",
            side: "long",
            entry_price: "2800.0",
            liquidation_price: "2100.0",
            current_value: "3050.5",
            distance_to_liquidation_pct: "31.1",
            risk_level: "safe"
          }
        ]
      }}
  """

  use Lux.Lens,
    name: "Hyperliquid Liquidation Risk",
    description: "Assesses liquidation risk for all open Hyperliquid perpetual positions",
    schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Account address to monitor",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        warning_threshold_pct: %{
          type: :number,
          description: "% distance below which to warn (default: 20)",
          default: 20.0
        },
        critical_threshold_pct: %{
          type: :number,
          description: "% distance below which to flag critical (default: 10)",
          default: 10.0
        }
      },
      required: ["address"]
    }

  import Lux.Python
  alias Lux.Config
  require Lux.Python
  require Logger

  @impl true
  def focus(input, agent) do
    address = Map.get(input, :address, "")
    warning_pct = Map.get(input, :warning_threshold_pct, 20.0)
    critical_pct = Map.get(input, :critical_threshold_pct, 10.0)
    agent_name = get_in(agent, [:agent, :name]) || "Unknown"

    Logger.info("Agent #{agent_name} monitoring liquidation risk for #{address}")

    with {:ok, api_url} <- {:ok, Config.hyperliquid_api_url()},
         {:ok, %{"success" => true}} <- Lux.Python.import_package("hyperliquid.info"),
         {:ok, result} <- assess_liquidation_risk(address, api_url, warning_pct, critical_pct) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => err}} ->
        {:error, "Package import failed: #{err}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp assess_liquidation_risk(address, api_url, warning_pct, critical_pct) do
    result =
      python variables: %{
               address: address,
               api_url: api_url,
               warning_pct: warning_pct,
               critical_pct: critical_pct
             } do
        ~PY"""
        from hyperliquid.info import Info

        def get_risk_level(distance_pct, warning, critical):
            if distance_pct is None:
                return "no_liquidation_risk"
            if distance_pct <= critical:
                return "critical"
            elif distance_pct <= warning:
                return "warning"
            else:
                return "safe"

        try:
            info = Info(api_url, skip_ws=True)
            user_state = info.user_state(address)

            positions = []
            risk_levels = []

            for asset_pos in user_state.get("assetPositions", []):
                pos = asset_pos.get("position", {})
                coin = pos.get("coin", "")

                size_str = pos.get("szi", "0")
                size = float(size_str)

                if size == 0:
                    continue

                side = "long" if size > 0 else "short"
                entry_px = pos.get("entryPx", "0")
                liq_px_str = pos.get("liquidationPx")

                # Estimate current price from position value
                pos_val = float(pos.get("positionValue", "0"))
                current_px = pos_val / abs(size) if size != 0 else 0.0

                # Calculate distance to liquidation
                if liq_px_str and current_px > 0:
                    liq_px = float(liq_px_str)
                    if side == "long":
                        distance_pct = ((current_px - liq_px) / current_px) * 100
                    else:
                        distance_pct = ((liq_px - current_px) / current_px) * 100
                    distance_pct = round(max(0.0, distance_pct), 2)
                else:
                    liq_px = None
                    distance_pct = None

                risk_level = get_risk_level(distance_pct, warning_pct, critical_pct)
                risk_levels.append(risk_level)

                positions.append({
                    "coin": coin,
                    "side": side,
                    "entry_price": entry_px,
                    "liquidation_price": str(liq_px) if liq_px is not None else None,
                    "current_value": str(round(current_px, 6)),
                    "distance_to_liquidation_pct": str(distance_pct) if distance_pct is not None else None,
                    "risk_level": risk_level
                })

            # Overall risk = worst individual risk
            risk_priority = {"critical": 3, "warning": 2, "safe": 1, "no_liquidation_risk": 0}
            if risk_levels:
                overall_risk = max(risk_levels, key=lambda r: risk_priority.get(r, 0))
            else:
                overall_risk = "safe"

            {
                "address": address,
                "overall_risk": overall_risk,
                "positions": positions
            }
        except Exception as e:
            {"error": str(e)}
        """
      end

    if Map.has_key?(result, "error") do
      {:error, result["error"]}
    else
      positions = Enum.map(result["positions"], fn pos ->
        %{
          coin: pos["coin"],
          side: pos["side"],
          entry_price: pos["entry_price"],
          liquidation_price: pos["liquidation_price"],
          current_value: pos["current_value"],
          distance_to_liquidation_pct: pos["distance_to_liquidation_pct"],
          risk_level: pos["risk_level"]
        }
      end)

      {:ok, %{
        address: result["address"],
        overall_risk: result["overall_risk"],
        positions: positions
      }}
    end
  end
end

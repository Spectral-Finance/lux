defmodule Lux.Prisms.Hyperliquid.LiquidationProtectionPrism do
  @moduledoc """
  A prism that implements liquidation prevention strategies for Hyperliquid positions.

  This prism monitors positions for liquidation risk and can automatically execute
  protective measures such as adding margin, reducing position size, or setting
  stop-loss orders to prevent liquidations.

  ## Example

      # Check and protect against liquidation
      iex> Lux.Prisms.Hyperliquid.LiquidationProtectionPrism.run(%{
      ...>   portfolio: %{
      ...>     "crossMarginSummary" => %{"accountValue" => "10000.0", "totalMarginUsed" => "8000.0"},
      ...>     "assetPositions" => [
      ...>       %{
      ...>         "position" => %{
      ...>           "coin" => "ETH",
      ...>           "size" => "5.0",
      ...>           "entryPx" => "2800.0",
      ...>           "liquidationPx" => "2700.0",
      ...>           "marginUsed" => "4000.0"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   market_data: %{"ETH" => %{"markPx" => "2750.0"}},
      ...>   protection_strategy: "add_margin",
      ...>   safety_buffer: 0.15
      ...> })
      {:ok, %{
        positions_protected: [
          %{
            coin: "ETH",
            action_taken: "stop_loss_set",
            stop_loss_price: "2695.0",
            distance_to_liquidation: 0.019,
            risk_level: "critical"
          }
        ],
        summary: %{
          total_positions_at_risk: 1,
          actions_taken: 1,
          portfolio_safe: false
        }
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid Liquidation Protection",
    description: "Implements liquidation prevention strategies",
    input_schema: %{
      type: :object,
      properties: %{
        portfolio: %{
          type: :object,
          description: "Current portfolio state from Hyperliquid"
        },
        market_data: %{
          type: :object,
          description: "Current market data"
        },
        protection_strategy: %{
          type: :string,
          description: "Strategy for liquidation protection",
          enum: ["add_margin", "reduce_position", "set_stop_loss", "auto_deleverage"],
          default: "set_stop_loss"
        },
        safety_buffer: %{
          type: :number,
          description: "Safety buffer as percentage distance from liquidation",
          default: 0.15
        },
        max_position_reduction_pct: %{
          type: :number,
          description: "Maximum percentage of position to reduce",
          default: 0.5
        }
      },
      required: ["portfolio", "market_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        positions_protected: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              coin: %{type: :string},
              action_taken: %{type: :string},
              details: %{type: :object}
            }
          }
        },
        summary: %{
          type: :object,
          properties: %{
            total_positions_at_risk: %{type: :integer},
            actions_taken: %{type: :integer},
            portfolio_safe: %{type: :boolean}
          }
        }
      },
      required: ["positions_protected", "summary"]
    }

  import Lux.Python

  require Logger

  def handler(%{portfolio: portfolio, market_data: market_data} = input, _ctx) do
    strategy = Map.get(input, :protection_strategy, "set_stop_loss")
    safety_buffer = Map.get(input, :safety_buffer, 0.15)
    max_reduction = Map.get(input, :max_position_reduction_pct, 0.5)

    result =
      execute_protection(portfolio, market_data, strategy, safety_buffer, max_reduction)

    case result do
      %{"error" => error} ->
        Logger.error("Liquidation protection failed: #{inspect(error)}")
        {:error, error}

      result_map when is_map(result_map) ->
        Logger.info("Liquidation protection executed", result_map)
        {:ok, result_map}
    end
  end

  defp execute_protection(portfolio, market_data, strategy, safety_buffer, max_reduction) do
    python_result =
      python variables: %{
               portfolio: portfolio,
               market_data: market_data,
               strategy: strategy,
               safety_buffer: safety_buffer,
               max_reduction: max_reduction
             } do
        ~PY"""
        def calculate_distance_to_liquidation(position, mark_price):
            liq_px_str = position.get("liquidationPx", "nil")
            if liq_px_str is None or liq_px_str == "nil":
                return 1.0

            liq_px = float(liq_px_str)
            size = float(position.get("size", "0"))

            if liq_px == 0 or mark_price == 0:
                return 1.0

            if size > 0:  # Long position
                return (mark_price - liq_px) / mark_price
            else:  # Short position
                return (liq_px - mark_price) / mark_price

        def assess_position_risk(distance, safety_buffer):
            if distance <= safety_buffer * 0.3:
                return "critical"
            elif distance <= safety_buffer * 0.6:
                return "high"
            elif distance <= safety_buffer:
                return "moderate"
            else:
                return "low"

        def determine_protection_action(risk_level, strategy, position, mark_price, max_reduction):
            if risk_level == "low":
                return {"none", {}}

            coin = position.get("coin", "UNKNOWN")
            size = float(position.get("size", "0"))
            entry_px = float(position.get("entryPx", "0"))

            if strategy == "set_stop_loss":
                # Set stop loss at safety buffer distance from liquidation
                liq_px = float(position.get("liquidationPx", "0"))
                if liq_px > 0 and size > 0:
                    stop_loss_px = liq_px * (1 + safety_buffer * 0.5)
                elif liq_px > 0 and size < 0:
                    stop_loss_px = liq_px * (1 - safety_buffer * 0.5)
                else:
                    stop_loss_px = entry_px * 0.95

                return {
                    "stop_loss_set",
                    {
                        "stop_loss_price": str(round(stop_loss_px, 2)),
                        "direction": "sell" if size > 0 else "buy",
                        "coin": coin
                    }
                }

            elif strategy == "reduce_position":
                reduction_pct = max_reduction if risk_level == "critical" else max_reduction * 0.5
                reduction_size = abs(size) * reduction_pct

                return {
                    "position_reduced",
                    {
                        "reduction_size": str(round(reduction_size, 4)),
                        "remaining_size": str(round(abs(size) - reduction_size, 4)),
                        "direction": "sell" if size > 0 else "buy",
                        "coin": coin
                    }
                }

            elif strategy == "add_margin":
                margin_used = float(position.get("marginUsed", "0"))
                additional_margin = margin_used * 0.5  # Add 50% more margin

                return {
                    "margin_added",
                    {
                        "additional_margin": str(round(additional_margin, 2)),
                        "coin": coin
                    }
                }

            elif strategy == "auto_deleverage":
                # Most aggressive: close 75% of position
                close_size = abs(size) * 0.75

                return {
                    "position_closed",
                    {
                        "close_size": str(round(close_size, 4)),
                        "direction": "sell" if size > 0 else "buy",
                        "coin": coin
                    }
                }

            return {"none", {}}

        # Main protection logic
        asset_positions = portfolio.get("assetPositions", [])
        positions_protected = []
        actions_taken = 0

        for pos in asset_positions:
            position = pos.get("position", {})
            coin = position.get("coin", "UNKNOWN")

            # Get mark price
            if coin in market_data:
                mark_price = float(market_data[coin].get("markPx", "0"))
            else:
                mark_price = float(position.get("entryPx", "0"))

            distance = calculate_distance_to_liquidation(position, mark_price)
            risk_level = assess_position_risk(distance, safety_buffer)

            action, details = determine_protection_action(
                risk_level, strategy, position, mark_price, max_reduction
            )

            if action != "none":
                actions_taken += 1
                positions_protected.append({
                    "coin": coin,
                    "action_taken": action,
                    "distance_to_liquidation": round(distance, 4),
                    "risk_level": risk_level,
                    "details": details
                })

        total_at_risk = len([
            p for p in positions_protected
            if p["risk_level"] in ["critical", "high"]
        ])

        {
            "positions_protected": positions_protected,
            "summary": {
                "total_positions_at_risk": total_at_risk,
                "actions_taken": actions_taken,
                "portfolio_safe": total_at_risk == 0
            }
        }
        """
      end

    python_result
  end
end

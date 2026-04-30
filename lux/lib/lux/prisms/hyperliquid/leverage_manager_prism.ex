defmodule Lux.Prisms.Hyperliquid.LeverageManagerPrism do
  @moduledoc """
  A prism that calculates and manages optimal leverage settings for Hyperliquid positions.

  This prism analyzes portfolio state, market conditions, and risk parameters to determine
  optimal leverage levels for new or existing positions. It considers account size,
  position concentration, volatility, and risk tolerance.

  ## Example

      # Calculate optimal leverage for a new position
      iex> Lux.Prisms.Hyperliquid.LeverageManagerPrism.run(%{
      ...>   portfolio: %{
      ...>     "crossMarginSummary" => %{"accountValue" => "10000.0", "totalNtlPos" => "5000.0"},
      ...>     "assetPositions" => []
      ...>   },
      ...>   proposed_position: %{
      ...>     coin: "ETH",
      ...>     sz: 0.5,
      ...>     limit_px: 2800.0
      ...>   },
      ...>   market_data: %{"ETH" => %{"markPx" => "2800.0", "funding" => "0.00001"}},
      ...>   risk_tolerance: "moderate"
      ...> })
      {:ok, %{
        recommended_leverage: 3.0,
        max_safe_leverage: 5.0,
        current_leverage: 0.5,
        projected_leverage: 2.0,
        leverage_adjustment: "increase",
        risk_assessment: "low"
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid Leverage Manager",
    description: "Calculates and manages optimal leverage settings",
    input_schema: %{
      type: :object,
      properties: %{
        portfolio: %{
          type: :object,
          description: "Current portfolio state from Hyperliquid"
        },
        proposed_position: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            sz: %{type: :number},
            limit_px: %{type: :number}
          },
          required: ["coin", "sz", "limit_px"]
        },
        market_data: %{
          type: :object,
          description: "Current market data for relevant assets"
        },
        risk_tolerance: %{
          type: :string,
          description: "Risk tolerance level (conservative, moderate, aggressive)",
          enum: ["conservative", "moderate", "aggressive"],
          default: "moderate"
        },
        target_leverage: %{
          type: :number,
          description: "Optional target leverage to validate"
        }
      },
      required: ["portfolio", "proposed_position", "market_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        recommended_leverage: %{type: :number},
        max_safe_leverage: %{type: :number},
        current_leverage: %{type: :number},
        projected_leverage: %{type: :number},
        leverage_adjustment: %{type: :string},
        risk_assessment: %{type: :string}
      },
      required: [
        "recommended_leverage",
        "max_safe_leverage",
        "current_leverage",
        "projected_leverage",
        "leverage_adjustment",
        "risk_assessment"
      ]
    }

  import Lux.Python

  require Logger

  # Maximum leverage limits by risk tolerance
  @max_leverage %{
    "conservative" => 3.0,
    "moderate" => 5.0,
    "aggressive" => 10.0
  }

  def handler(%{portfolio: portfolio, proposed_position: position, market_data: market_data} = input, _ctx) do
    risk_tolerance = Map.get(input, :risk_tolerance, "moderate")
    target_leverage = Map.get(input, :target_leverage, nil)

    result =
      calculate_leverage(portfolio, position, market_data, risk_tolerance, target_leverage)

    case result do
      %{error: error} ->
        Logger.error("Leverage calculation failed: #{inspect(error)}")
        {:error, error}

      result_map when is_map(result_map) ->
        Logger.info("Leverage calculation completed", result_map)
        {:ok, result_map}
    end
  end

  defp calculate_leverage(portfolio, position, market_data, risk_tolerance, target_leverage) do
    python_result =
      python variables: %{
               portfolio: portfolio,
               position: position,
               market_data: market_data,
               risk_tolerance: risk_tolerance,
               target_leverage: target_leverage,
               max_leverage_conservative: @max_leverage["conservative"],
               max_leverage_moderate: @max_leverage["moderate"],
               max_leverage_aggressive: @max_leverage["aggressive"]
             } do
        ~PY"""
        def get_max_leverage(risk_tolerance):
            limits = {
                "conservative": max_leverage_conservative,
                "moderate": max_leverage_moderate,
                "aggressive": max_leverage_aggressive
            }
            return limits.get(risk_tolerance, max_leverage_moderate)

        def calculate_current_leverage(portfolio):
            margin_summary = portfolio.get("crossMarginSummary", {})
            account_value = float(margin_summary.get("accountValue", "0"))
            total_ntl_pos = float(margin_summary.get("totalNtlPos", "0"))

            if account_value == 0:
                return 0.0

            return total_ntl_pos / account_value

        def calculate_position_value(position, market_data):
            coin = position["coin"]
            sz = float(position["sz"])
            limit_px = float(position["limit_px"])

            if coin in market_data:
                mark_px = float(market_data[coin].get("markPx", str(limit_px)))
            else:
                mark_px = limit_px

            return sz * mark_px

        def calculate_projected_leverage(current_leverage, position_value, account_value):
            if account_value == 0:
                return current_leverage

            additional_leverage = position_value / account_value
            return current_leverage + additional_leverage

        def calculate_recommended_leverage(projected_leverage, max_leverage, risk_tolerance):
            # Conservative approach: recommend lower leverage
            if risk_tolerance == "conservative":
                return min(projected_leverage * 0.8, max_leverage * 0.6)
            elif risk_tolerance == "aggressive":
                return min(projected_leverage * 1.2, max_leverage)
            else:  # moderate
                return min(projected_leverage, max_leverage * 0.8)

        def assess_risk(projected_leverage, max_leverage):
            ratio = projected_leverage / max_leverage if max_leverage > 0 else 1.0

            if ratio > 0.9:
                return "critical"
            elif ratio > 0.7:
                return "high"
            elif ratio > 0.5:
                return "moderate"
            elif ratio > 0.3:
                return "low"
            else:
                return "very_low"

        # Main calculation
        max_leverage = get_max_leverage(risk_tolerance)
        current_leverage = calculate_current_leverage(portfolio)
        position_value = calculate_position_value(position, market_data)

        margin_summary = portfolio.get("crossMarginSummary", {})
        account_value = float(margin_summary.get("accountValue", "0"))

        projected_leverage = calculate_projected_leverage(current_leverage, position_value, account_value)

        if target_leverage is not None:
            recommended_leverage = min(float(target_leverage), max_leverage)
        else:
            recommended_leverage = calculate_recommended_leverage(
                projected_leverage, max_leverage, risk_tolerance
            )

        # Determine adjustment direction
        if recommended_leverage > current_leverage:
            adjustment = "increase"
        elif recommended_leverage < current_leverage:
            adjustment = "decrease"
        else:
            adjustment = "maintain"

        risk_assessment = assess_risk(projected_leverage, max_leverage)

        {
            "recommended_leverage": round(recommended_leverage, 2),
            "max_safe_leverage": round(max_leverage, 2),
            "current_leverage": round(current_leverage, 2),
            "projected_leverage": round(projected_leverage, 2),
            "leverage_adjustment": adjustment,
            "risk_assessment": risk_assessment
        }
        """
      end

    python_result
  end
end

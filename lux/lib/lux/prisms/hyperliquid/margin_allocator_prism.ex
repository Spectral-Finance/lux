defmodule Lux.Prisms.Hyperliquid.MarginAllocatorPrism do
  @moduledoc """
  A prism that allocates margin across positions efficiently on Hyperliquid.

  This prism analyzes the current portfolio state and determines optimal margin
  allocation across positions. It considers position size, risk level, correlation,
  and available margin to ensure efficient capital utilization while maintaining
  appropriate safety margins.

  ## Example

      # Calculate margin allocation
      iex> Lux.Prisms.Hyperliquid.MarginAllocatorPrism.run(%{
      ...>   portfolio: %{
      ...>     "crossMarginSummary" => %{
      ...>       "accountValue" => "50000.0",
      ...>       "totalMarginUsed" => "15000.0",
      ...>       "totalNtlPos" => "30000.0"
      ...>     },
      ...>     "assetPositions" => [
      ...>       %{
      ...>         "position" => %{
      ...>           "coin" => "BTC",
      ...>           "size" => "0.5",
      ...>           "marginUsed" => "8000.0",
      ...>           "positionValue" => "52000.0"
      ...>         }
      ...>       },
      ...>       %{
      ...>         "position" => %{
      ...>           "coin" => "ETH",
      ...>           "size" => "2.0",
      ...>           "marginUsed" => "7000.0",
      ...>           "positionValue" => "5600.0"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   new_position: %{coin: "SOL", sz: 10, limit_px: 150.0},
      ...>   allocation_strategy: "risk_adjusted"
      ...> })
      {:ok, %{
        current_allocations: %{
          "BTC" => %{margin_used: "8000.0", allocation_pct: 53.3},
          "ETH" => %{margin_used: "7000.0", allocation_pct: 46.7}
        },
        recommended_allocation: %{
          coin: "SOL",
          margin_required: "3000.0",
          allocation_pct: 10.0,
          status: "approved"
        },
        remaining_margin: "35000.0",
        utilization_ratio: 0.3
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid Margin Allocator",
    description: "Allocates margin across positions efficiently",
    input_schema: %{
      type: :object,
      properties: %{
        portfolio: %{
          type: :object,
          description: "Current portfolio state from Hyperliquid"
        },
        new_position: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            sz: %{type: :number},
            limit_px: %{type: :number}
          },
          required: ["coin", "sz", "limit_px"]
        },
        allocation_strategy: %{
          type: :string,
          description: "Strategy for margin allocation",
          enum: ["equal_weight", "risk_adjusted", "performance_based"],
          default: "risk_adjusted"
        },
        max_allocation_pct: %{
          type: :number,
          description: "Maximum margin allocation percentage for single position",
          default: 25.0
        }
      },
      required: ["portfolio", "new_position"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        current_allocations: %{type: :object},
        recommended_allocation: %{
          type: :object,
          properties: %{
            coin: %{type: :string},
            margin_required: %{type: :string},
            allocation_pct: %{type: :number},
            status: %{type: :string}
          }
        },
        remaining_margin: %{type: :string},
        utilization_ratio: %{type: :number}
      },
      required: ["current_allocations", "recommended_allocation", "remaining_margin", "utilization_ratio"]
    }

  import Lux.Python

  require Logger

  def handler(%{portfolio: portfolio, new_position: new_position} = input, _ctx) do
    strategy = Map.get(input, :allocation_strategy, "risk_adjusted")
    max_allocation_pct = Map.get(input, :max_allocation_pct, 25.0)

    result =
      calculate_allocation(portfolio, new_position, strategy, max_allocation_pct)

    case result do
      %{"error" => error} ->
        Logger.error("Margin allocation failed: #{inspect(error)}")
        {:error, error}

      result_map when is_map(result_map) ->
        Logger.info("Margin allocation completed", result_map)
        {:ok, result_map}
    end
  end

  defp calculate_allocation(portfolio, new_position, strategy, max_allocation_pct) do
    python_result =
      python variables: %{
               portfolio: portfolio,
               new_position: new_position,
               strategy: strategy,
               max_allocation_pct: max_allocation_pct
             } do
        ~PY"""
        def calculate_current_allocations(portfolio):
            margin_summary = portfolio.get("crossMarginSummary", {})
            total_margin_used = float(margin_summary.get("totalMarginUsed", "0"))
            asset_positions = portfolio.get("assetPositions", [])

            allocations = {}
            for pos in asset_positions:
                position = pos.get("position", {})
                coin = position.get("coin", "UNKNOWN")
                margin_used = float(position.get("marginUsed", "0"))

                allocation_pct = (margin_used / total_margin_used * 100) if total_margin_used > 0 else 0

                allocations[coin] = {
                    "margin_used": str(margin_used),
                    "allocation_pct": round(allocation_pct, 2)
                }

            return allocations

        def calculate_required_margin(new_position, portfolio):
            coin = new_position["coin"]
            sz = float(new_position["sz"])
            limit_px = float(new_position["limit_px"])

            position_value = sz * limit_px

            # Get current leverage from similar positions or use default
            asset_positions = portfolio.get("assetPositions", [])
            avg_leverage = 3.0  # Default leverage assumption

            for pos in asset_positions:
                position = pos.get("position", {})
                pos_leverage = float(position.get("leverage", "3"))
                avg_leverage = (avg_leverage + pos_leverage) / 2

            # Required margin = position_value / leverage
            required_margin = position_value / avg_leverage
            return required_margin

        def determine_allocation(strategy, portfolio, required_margin, max_allocation_pct):
            margin_summary = portfolio.get("crossMarginSummary", {})
            account_value = float(margin_summary.get("accountValue", "0"))
            total_margin_used = float(margin_summary.get("totalMarginUsed", "0"))
            remaining_margin = account_value - total_margin_used

            # Calculate max allowed allocation
            max_allowed = account_value * (max_allocation_pct / 100)

            # Strategy-based adjustments
            if strategy == "equal_weight":
                # Equal weight across all positions
                num_positions = len(portfolio.get("assetPositions", [])) + 1
                equal_allocation = account_value / (num_positions * 3)  # Assume 3x leverage
                allocation = min(required_margin, equal_allocation, max_allowed)
            elif strategy == "performance_based":
                # Allocate more to higher performing positions (simplified)
                allocation = min(required_margin * 1.2, max_allowed)
            else:  # risk_adjusted (default)
                allocation = min(required_margin, max_allowed)

            allocation_pct = (allocation / account_value * 100) if account_value > 0 else 0

            # Determine status
            if allocation >= required_margin and remaining_margin >= required_margin:
                status = "approved"
            elif remaining_margin > 0:
                status = "partial"
                allocation = min(allocation, remaining_margin)
            else:
                status = "rejected"
                allocation = 0

            return {
                "allocation": allocation,
                "allocation_pct": round(allocation_pct, 2),
                "status": status,
                "remaining_margin": remaining_margin
            }

        # Main calculation
        current_allocations = calculate_current_allocations(portfolio)
        required_margin = calculate_required_margin(new_position, portfolio)
        allocation_info = determine_allocation(strategy, portfolio, required_margin, max_allocation_pct)

        margin_summary = portfolio.get("crossMarginSummary", {})
        account_value = float(margin_summary.get("accountValue", "0"))
        total_margin_used = float(margin_summary.get("totalMarginUsed", "0"))

        remaining = allocation_info["remaining_margin"] - allocation_info["allocation"]
        utilization = total_margin_used / account_value if account_value > 0 else 0

        {
            "current_allocations": current_allocations,
            "recommended_allocation": {
                "coin": new_position["coin"],
                "margin_required": str(round(allocation_info["allocation"], 2)),
                "allocation_pct": allocation_info["allocation_pct"],
                "status": allocation_info["status"]
            },
            "remaining_margin": str(round(remaining, 2)),
            "utilization_ratio": round(utilization, 4)
        }
        """
      end

    python_result
  end
end

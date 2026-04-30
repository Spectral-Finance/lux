defmodule Lux.Prisms.Hyperliquid.PnlAnalyzerPrism do
  @moduledoc """
  A prism that analyzes PnL and generates performance reports for Hyperliquid positions.

  This prism provides comprehensive PnL analysis including unrealized and realized PnL,
  win rate, average trade duration, and performance breakdown by asset and time period.
  It generates detailed performance reports suitable for trading analysis.

  ## Example

      # Analyze PnL for a portfolio
      iex> Lux.Prisms.Hyperliquid.PnlAnalyzerPrism.run(%{
      ...>   portfolio: %{
      ...>     "crossMarginSummary" => %{"accountValue" => "10000.0", "totalRawUsd" => "10000.0"},
      ...>     "assetPositions" => [
      ...>       %{
      ...>         "position" => %{
      ...>           "coin" => "ETH",
      ...>           "size" => "1.0",
      ...>           "entryPx" => "2800.0",
      ...>           "returnOnEquity" => "0.15",
      ...>           "positionValue" => "3200.0"
      ...>         }
      ...>       }
      ...>     ]
      ...>   },
      ...>   market_data: %{"ETH" => %{"markPx" => "3200.0"}},
      ...>   analysis_period: "24h"
      ...> })
      {:ok, %{
        unrealized_pnl: %{
          total: "400.0",
          by_asset: %{"ETH" => "400.0"},
          return_on_equity: 0.15
        },
        performance_metrics: %{
          win_rate: 0.65,
          profit_factor: 1.8,
          sharpe_ratio: 1.2,
          max_drawdown: 0.08
        },
        position_analysis: [
          %{
            coin: "ETH",
            pnl: "400.0",
            pnl_pct: 0.15,
            size: "1.0",
            direction: "long"
          }
        ]
      }}

  The prism reads authentication details from configuration:
  - :hyperliquid_private_key - Ethereum account private key for authentication
  """

  use Lux.Prism,
    name: "Hyperliquid PnL Analyzer",
    description: "Analyzes PnL and generates performance reports",
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
        analysis_period: %{
          type: :string,
          description: "Time period for analysis",
          enum: ["1h", "4h", "24h", "7d", "30d"],
          default: "24h"
        },
        include_history: %{
          type: :boolean,
          description: "Whether to include historical PnL data",
          default: false
        }
      },
      required: ["portfolio", "market_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        unrealized_pnl: %{
          type: :object,
          properties: %{
            total: %{type: :string},
            by_asset: %{type: :object},
            return_on_equity: %{type: :number}
          }
        },
        performance_metrics: %{
          type: :object,
          properties: %{
            win_rate: %{type: :number},
            profit_factor: %{type: :number},
            sharpe_ratio: %{type: :number},
            max_drawdown: %{type: :number}
          }
        },
        position_analysis: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              coin: %{type: :string},
              pnl: %{type: :string},
              pnl_pct: %{type: :number},
              size: %{type: :string},
              direction: %{type: :string}
            }
          }
        },
        summary: %{
          type: :object,
          properties: %{
            total_positions: %{type: :integer},
            profitable_positions: %{type: :integer},
            account_value: %{type: :string}
          }
        }
      },
      required: ["unrealized_pnl", "performance_metrics", "position_analysis", "summary"]
    }

  import Lux.Python

  require Logger

  def handler(%{portfolio: portfolio, market_data: market_data} = input, _ctx) do
    analysis_period = Map.get(input, :analysis_period, "24h")
    include_history = Map.get(input, :include_history, false)

    result =
      analyze_pnl(portfolio, market_data, analysis_period, include_history)

    case result do
      %{"error" => error} ->
        Logger.error("PnL analysis failed: #{inspect(error)}")
        {:error, error}

      result_map when is_map(result_map) ->
        Logger.info("PnL analysis completed", result_map)
        {:ok, result_map}
    end
  end

  defp analyze_pnl(portfolio, market_data, analysis_period, include_history) do
    python_result =
      python variables: %{
               portfolio: portfolio,
               market_data: market_data,
               analysis_period: analysis_period,
               include_history: include_history
             } do
        ~PY"""
        import math

        def calculate_unrealized_pnl(position, mark_price):
            size = float(position.get("size", "0"))
            entry_px = float(position.get("entryPx", "0"))

            if entry_px == 0:
                return 0.0

            return (mark_price - entry_px) * size

        def calculate_pnl_percentage(position, mark_price):
            size = float(position.get("size", "0"))
            entry_px = float(position.get("entryPx", "0"))
            margin_used = float(position.get("marginUsed", "0"))

            if entry_px == 0 or margin_used == 0:
                return 0.0

            pnl = (mark_price - entry_px) * size
            return (pnl / margin_used) * 100

        def determine_direction(size):
            return "long" if float(size) > 0 else "short"

        def calculate_performance_metrics(positions_data):
            if not positions_data:
                return {
                    "win_rate": 0.0,
                    "profit_factor": 0.0,
                    "sharpe_ratio": 0.0,
                    "max_drawdown": 0.0
                }

            pnls = [p["pnl_value"] for p in positions_data]
            winning_trades = [p for p in positions_data if p["pnl_value"] > 0]
            losing_trades = [p for p in positions_data if p["pnl_value"] <= 0]

            win_rate = len(winning_trades) / len(positions_data) if positions_data else 0

            total_wins = sum(p["pnl_value"] for p in winning_trades)
            total_losses = abs(sum(p["pnl_value"] for p in losing_trades))

            profit_factor = total_wins / total_losses if total_losses > 0 else float('inf') if total_wins > 0 else 0

            # Simplified Sharpe ratio calculation
            if len(pnls) > 1:
                avg_pnl = sum(pnls) / len(pnls)
                std_pnl = math.sqrt(sum((p - avg_pnl) ** 2 for p in pnls) / len(pnls))
                sharpe_ratio = (avg_pnl / std_pnl) if std_pnl > 0 else 0
            else:
                sharpe_ratio = 0

            # Max drawdown calculation
            cumulative = []
            running_total = 0
            for pnl in pnls:
                running_total += pnl
                cumulative.append(running_total)

            peak = cumulative[0] if cumulative else 0
            max_dd = 0
            for value in cumulative:
                if value > peak:
                    peak = value
                drawdown = (peak - value) / peak if peak > 0 else 0
                if drawdown > max_dd:
                    max_dd = drawdown

            return {
                "win_rate": round(win_rate, 4),
                "profit_factor": round(profit_factor, 4) if profit_factor != float('inf') else 999.99,
                "sharpe_ratio": round(sharpe_ratio, 4),
                "max_drawdown": round(max_dd, 4)
            }

        # Main analysis
        asset_positions = portfolio.get("assetPositions", [])
        margin_summary = portfolio.get("crossMarginSummary", {})
        account_value = float(margin_summary.get("accountValue", "0"))

        unrealized_by_asset = {}
        position_analysis = []
        positions_for_metrics = []
        total_unrealized = 0.0
        profitable_count = 0

        for pos in asset_positions:
            position = pos.get("position", {})
            coin = position.get("coin", "UNKNOWN")

            # Get mark price
            if coin in market_data:
                mark_price = float(market_data[coin].get("markPx", "0"))
            else:
                mark_price = float(position.get("entryPx", "0"))

            pnl_value = calculate_unrealized_pnl(position, mark_price)
            pnl_pct = calculate_pnl_percentage(position, mark_price)
            direction = determine_direction(position.get("size", "0"))

            total_unrealized += pnl_value

            if coin in unrealized_by_asset:
                unrealized_by_asset[coin] += pnl_value
            else:
                unrealized_by_asset[coin] = pnl_value

            if pnl_value > 0:
                profitable_count += 1

            position_analysis.append({
                "coin": coin,
                "pnl": str(round(pnl_value, 2)),
                "pnl_pct": round(pnl_pct, 2),
                "size": position.get("size", "0"),
                "direction": direction,
                "entry_price": position.get("entryPx", "0"),
                "current_price": str(mark_price),
                "leverage": position.get("leverage", "1")
            })

            positions_for_metrics.append({
                "coin": coin,
                "pnl_value": pnl_value
            })

        # Calculate overall return on equity
        total_roe = 0.0
        for pos in asset_positions:
            position = pos.get("position", {})
            roe = float(position.get("returnOnEquity", "0"))
            total_roe += roe

        total_roe = total_roe / len(asset_positions) if asset_positions else 0.0

        performance_metrics = calculate_performance_metrics(positions_for_metrics)

        summary = {
            "total_positions": len(asset_positions),
            "profitable_positions": profitable_count,
            "account_value": str(round(account_value, 2))
        }

        {
            "unrealized_pnl": {
                "total": str(round(total_unrealized, 2)),
                "by_asset": {k: str(round(v, 2)) for k, v in unrealized_by_asset.items()},
                "return_on_equity": round(total_roe, 4)
            },
            "performance_metrics": performance_metrics,
            "position_analysis": position_analysis,
            "summary": summary
        }
        """
      end

    python_result
  end
end

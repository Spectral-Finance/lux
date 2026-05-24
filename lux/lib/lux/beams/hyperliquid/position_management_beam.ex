defmodule Lux.Beams.Hyperliquid.PositionManagementBeam do
  @moduledoc """
  A beam that provides comprehensive position management for Hyperliquid perpetual trading.

  This beam orchestrates position monitoring, liquidation protection, and PnL tracking
  to give a complete view of open positions and their risk status.

  ## Example

      Lux.Beams.Hyperliquid.PositionManagementBeam.run(%{
        address: "0x0403369c02199a0cb827f4d6492927e9fa5668d5",
        warning_threshold: 0.2,
        critical_threshold: 0.1
      })
      {:ok, %{
        status: "success",
        positions: [...],
        liquidation_monitor: %{...},
        pnl_tracker: %{...}
      }}

  The beam combines:
  1. User state and position data (HyperliquidUserStatePrism)
  2. Market prices and token info (HyperliquidTokenInfoPrism)
  3. Liquidation risk monitoring (HyperliquidLiquidationMonitorPrism)
  4. PnL tracking (HyperliquidPnLTrackerPrism)
  """

  use Lux.Beam,
    name: "Hyperliquid Position Management",
    description: "Comprehensive position management for Hyperliquid perpetual trading",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{
          type: :string,
          description: "Trading account address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        warning_threshold: %{
          type: :number,
          description: "Liquidation warning threshold (0-1, default 0.2)",
          default: 0.2
        },
        critical_threshold: %{
          type: :number,
          description: "Liquidation critical threshold (0-1, default 0.1)",
          default: 0.1
        }
      },
      required: ["address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{
          type: :string,
          description: "Overall position management status"
        },
        position_data: %{
          type: :object,
          description: "Complete position and risk data"
        }
      },
      required: ["status", "position_data"]
    },
    generate_execution_log: true

  alias Lux.Config
  alias Lux.Prisms.Hyperliquid.HyperliquidLiquidationMonitorPrism
  alias Lux.Prisms.Hyperliquid.HyperliquidPnLTrackerPrism

  require Logger

  sequence do
    # Monitor liquidation risk for all positions
    step(:liquidation_monitor, HyperliquidLiquidationMonitorPrism, %{
      address: [:input, :address],
      warning_threshold: [:input, :warning_threshold],
      critical_threshold: [:input, :critical_threshold]
    })

    # Track PnL across all positions
    step(:pnl_tracker, HyperliquidPnLTrackerPrism, %{
      address: [:input, :address]
    })
  end

  @doc """
  Aggregates the results from both steps into a comprehensive position management response.
  Called automatically by the beam after all steps complete.
  """
  def after_sequence(results, _input) do
    liquidation = results[:liquidation_monitor] || %{}
    pnl = results[:pnl_tracker] || %{}

    # Determine overall status based on liquidation risk
    overall_status =
      case liquidation do
        %{summary: %{"critical_count" => count}} when count > 0 -> "critical"
        %{summary: %{"warning_count" => count}} when count > 0 -> "warning"
        _ -> "healthy"
      end

    {:ok, %{
      status: overall_status,
      position_data: %{
        liquidation_monitor: liquidation,
        pnl_tracker: pnl
      }
    }}
  end
end
defmodule Lux.Beams.Trading.Hyperliquid.PerpetualTradingBeam do
  @moduledoc """
  Automated Hyperliquid Perpetual Trading & Risk Orchestration Beam.
  Orchestrates:
  1. Position valuation & PnL calculation
  2. Liquidation proximity risk check
  3. Account margin & leverage evaluation
  4. Automated de-risking and protection evaluation
  """

  use Lux.Beam,
    name: "Hyperliquid Perpetual Trading Beam",
    description: "Tracks positions, evaluates liquidation danger, audits account margin, and plans de-risking",
    input_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string, default: "ETH"},
        sz: %{type: :number, default: 1.0},
        entry_px: %{type: :number},
        mark_px: %{type: :number},
        leverage: %{type: :integer, default: 10},
        wallet_balance: %{type: :number, default: 5000.0}
      },
      required: ["coin", "sz", "entry_px", "mark_px"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        coin: %{type: :string},
        direction: %{type: :string},
        unrealized_pnl: %{type: :number},
        liquidation_px: %{type: :number},
        risk_tier: %{type: :string},
        derisk_required: %{type: :boolean},
        margin_ratio: %{type: :number}
      },
      required: ["coin", "direction", "unrealized_pnl", "liquidation_px", "risk_tier"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Trading.Hyperliquid.TrackPositionsPrism
  alias Lux.Prisms.Trading.Hyperliquid.CheckLiquidationRiskPrism
  alias Lux.Prisms.Trading.Hyperliquid.ManageMarginPrism
  alias Lux.Prisms.Trading.Hyperliquid.AutoDeriskPrism

  sequence do
    step(:track, TrackPositionsPrism, %{
      coin: [:input, :coin],
      sz: [:input, :sz],
      entry_px: [:input, :entry_px],
      mark_px: [:input, :mark_px],
      leverage: [:input, :leverage]
    })

    step(:liq_check, CheckLiquidationRiskPrism, %{
      position: [:steps, :track, :result]
    })

    step(:derisk, AutoDeriskPrism, %{
      position: [:steps, :track, :result]
    })

    step(:margin, ManageMarginPrism, %{
      wallet_balance: [:input, :wallet_balance],
      positions: [[:steps, :track, :result]]
    })

    step(:return, Lux.Prisms.NoOp, %{
      coin: [:steps, :track, :result, :coin],
      direction: [:steps, :track, :result, :direction],
      unrealized_pnl: [:steps, :track, :result, :unrealized_pnl],
      liquidation_px: [:steps, :track, :result, :liquidation_px],
      risk_tier: [:steps, :liq_check, :result, :tier],
      derisk_required: [:steps, :derisk, :result, :derisk_required],
      margin_ratio: [:steps, :margin, :result, :margin_ratio]
    })
  end
end

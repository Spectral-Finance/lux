defmodule Lux.Beams.Analytics.Defi.DefiAnalyticsBeam do
  @moduledoc """
  A coordinated workflow beam for comprehensive DeFi protocol analytics:
  1. Inspects TVL metrics and multi-chain TVL distribution via ProtocolTvlPrism
  2. Scans for critical drawdown anomalies or depeg events via DeFiAlertsPrism
  3. Filters yield farming pool opportunities via YieldPoolsPrism
  """

  use Lux.Beam,
    name: "DeFi Protocol Analytics Beam",
    description: "Evaluates protocol TVL, monitors drawdown alerts, and analyzes yield opportunities",
    input_schema: %{
      type: :object,
      properties: %{
        protocol: %{type: :string, description: "Protocol slug or name"},
        protocol_data: %{type: :object, description: "Raw DeFiLlama TVL data"},
        pools: %{type: :array, default: []},
        min_tvl_usd: %{type: :number, default: 1_000_000.0},
        min_apy_pct: %{type: :number, default: 5.0}
      },
      required: ["protocol", "protocol_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        tvl_metrics: %{type: :object},
        alert_metrics: %{type: :object},
        yield_metrics: %{type: :object}
      },
      required: ["status"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Analytics.Defi.ProtocolTvlPrism
  alias Lux.Prisms.Analytics.Defi.DeFiAlertsPrism
  alias Lux.Prisms.Analytics.Defi.YieldPoolsPrism

  sequence do
    step(:tvl, ProtocolTvlPrism, %{
      protocol_data: [:input, :protocol_data]
    })

    step(:alerts, DeFiAlertsPrism, %{
      protocol: [:input, :protocol],
      change_1d_pct: [:steps, :tvl, :result, :change_1d_pct]
    })

    step(:yields, YieldPoolsPrism, %{
      pools: [:input, :pools],
      min_tvl_usd: [:input, :min_tvl_usd],
      min_apy_pct: [:input, :min_apy_pct]
    })
  end
end

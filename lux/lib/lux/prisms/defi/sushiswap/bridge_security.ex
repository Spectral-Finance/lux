defmodule Lux.Prisms.Defi.SushiSwap.BridgeSecurityPrism do
  @moduledoc """
  Validates cross-chain swap safety, checking slippage tolerances and fee ratios.
  """

  use Lux.Prism,
    name: "SushiSwap Bridge Security",
    description: "Evaluates cross-chain quote safety, fee ratio %, and slippage thresholds",
    input_schema: %{
      type: :object,
      properties: %{
        amount_in_usd: %{type: :number, description: "Input transfer amount in USD"},
        fee_usd: %{type: :number, description: "Estimated total bridge fee in USD"},
        est_out_usd: %{type: :number, description: "Estimated output value in USD"},
        max_slippage_pct: %{type: :number, default: 1.0}
      },
      required: ["amount_in_usd", "fee_usd", "est_out_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        safe?: %{type: :boolean},
        slippage_pct: %{type: :number},
        fee_ratio_pct: %{type: :number},
        warning: %{type: :string}
      },
      required: ["safe?", "slippage_pct", "fee_ratio_pct"]
    }

  alias Lux.Defi.SushiSwap.BridgeMonitor

  def handler(input, _ctx) do
    amount_in = (Map.get(input, :amount_in_usd) || Map.get(input, "amount_in_usd", 0.0)) * 1.0
    fee = (Map.get(input, :fee_usd) || Map.get(input, "fee_usd", 0.0)) * 1.0
    est_out = (Map.get(input, :est_out_usd) || Map.get(input, "est_out_usd", 0.0)) * 1.0
    max_slip = (Map.get(input, :max_slippage_pct) || Map.get(input, "max_slippage_pct", 1.0)) * 1.0

    result = BridgeMonitor.verify_bridge_safety(amount_in, fee, est_out, max_slip)
    {:ok, result}
  end
end

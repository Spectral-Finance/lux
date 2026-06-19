defmodule Lux.Beams.Hyperliquid.LiquidationProtectionBeam do
  @moduledoc """
  Monitors positions for liquidation risk and triggers protective actions.
  """
  use Lux.Beam,
    name: "Hyperliquid Liquidation Protection",
    description: "Monitors liquidation risk and triggers protective actions like reducing position size",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Account address"},
        risk_threshold: %{type: :number, default: 0.8}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        liquidation_price: %{type: :number},
        current_risk: %{type: :number},
        action_required: %{type: :boolean},
        recommended_action: %{type: :string}
      }
    }

  def run(input) do
    risk_data = check_liquidation_risk(input.address)
    action_required = risk_data.risk > input.risk_threshold

    {:ok, %{
      liquidation_price: risk_data.liq_price,
      current_risk: risk_data.risk,
      action_required: action_required,
      recommended_action: if(action_required, do: "reduce_position", else: "none")
    }}
  end

  defp check_liquidation_risk(_address) do
    # TODO: Integrate with Hyperliquid API
    %{liq_price: 2500.0, risk: 0.3}
  end
end

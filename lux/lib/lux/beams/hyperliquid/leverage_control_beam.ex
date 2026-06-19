defmodule Lux.Beams.Hyperliquid.LeverageControlBeam do
  @moduledoc """
  Monitors and controls leverage for Hyperliquid positions.
  """
  use Lux.Beam,
    name: "Hyperliquid Leverage Control",
    description: "Monitors leverage levels and enforces maximum leverage constraints",
    input_schema: %{
      type: :object,
      properties: %{
        address: %{type: :string, description: "Account address"},
        max_leverage: %{type: :number, default: 5.0}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        current_leverage: %{type: :number},
        within_limits: %{type: :boolean},
        warning: %{type: :string}
      }
    }

  def run(input) do
    leverage = fetch_current_leverage(input.address)
    within_limits = leverage <= input.max_leverage
    warning = if within_limits, do: "ok", else: "LEVERAGE EXCEEDS LIMIT"

    {:ok, %{
      current_leverage: leverage,
      within_limits: within_limits,
      warning: warning
    }}
  end

  defp fetch_current_leverage(_address) do
    # TODO: Integrate with Hyperliquid API
    1.5
  end
end

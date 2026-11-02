defmodule Lux.Prisms.Trading.Hyperliquid.AutoDeriskPrism do
  @moduledoc """
  Generates automated de-risking trade execution instructions to protect against liquidations.
  """

  use Lux.Prism,
    name: "Auto De-Risk Hyperliquid Position",
    description: "Generates protective market close or partial size reduction plans when liquidation is near",
    input_schema: %{
      type: :object,
      properties: %{
        position: %{type: :object, description: "Position map with coin, mark_px, liquidation_px, sz"}
      },
      required: ["position"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        derisk_required: %{type: :boolean},
        action: %{type: :string},
        close_size: %{type: :number},
        reason: %{type: :string}
      },
      required: ["derisk_required", "action", "close_size", "reason"]
    }

  alias Lux.Trading.Hyperliquid.LiquidationProtector

  def handler(input, _ctx) do
    raw_pos = Map.get(input, :position) || Map.get(input, "position", %{})

    pos = %{
      coin: Map.get(raw_pos, :coin) || Map.get(raw_pos, "coin", "ETH"),
      mark_px: (Map.get(raw_pos, :mark_px) || Map.get(raw_pos, "mark_px", 1.0)) * 1.0,
      liquidation_px: (Map.get(raw_pos, :liquidation_px) || Map.get(raw_pos, "liquidation_px", 0.0)) * 1.0,
      sz: (Map.get(raw_pos, :sz) || Map.get(raw_pos, "sz", 0.0)) * 1.0
    }

    result = LiquidationProtector.plan_derisk(pos)

    {:ok,
     %{
       derisk_required: result.derisk_required?,
       action: to_string(result.action),
       close_size: result.close_size,
       reason: result.reason
     }}
  end
end

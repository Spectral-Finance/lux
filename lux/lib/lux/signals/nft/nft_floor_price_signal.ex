defmodule Lux.Signals.NFT.NFTFloorPriceSignal do
  @moduledoc """
  Signal emitted when aggregated NFT floor prices or venue spreads update.
  """

  use Lux.SignalSchema,
    name: "NFT Floor Price Signal",
    description: "Emitted when cross-marketplace floor prices update",
    version: "1.0.0",
    compatibility: :full,
    schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        best_floor_price_eth: %{type: :number},
        best_floor_price_usd: %{type: :number},
        best_marketplace: %{type: :string},
        spread_eth: %{type: :number},
        spread_percent: %{type: :number},
        timestamp: %{type: :number}
      },
      required: ["collection_address", "best_floor_price_eth", "best_marketplace"]
    }

  use Lux.Signal, schema_id: __MODULE__
end

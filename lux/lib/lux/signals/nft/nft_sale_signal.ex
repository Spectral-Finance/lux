defmodule Lux.Signals.NFT.NFTSaleSignal do
  @moduledoc """
  Signal emitted on verified NFT sale events across OpenSea, Blur, or LooksRare.
  """

  use Lux.SignalSchema,
    name: "NFT Sale Event Signal",
    description: "Emitted on real-time NFT sale transactions",
    version: "1.0.0",
    compatibility: :full,
    schema: %{
      type: :object,
      properties: %{
        event_id: %{type: :string},
        marketplace: %{type: :string},
        collection_address: %{type: :string},
        token_id: %{type: :string},
        price_eth: %{type: :number},
        price_usd: %{type: :number},
        payment_token: %{type: :string},
        buyer_address: %{type: :string},
        seller_address: %{type: :string},
        transaction_hash: %{type: :string},
        timestamp: %{type: :number}
      },
      required: [
        "event_id",
        "marketplace",
        "collection_address",
        "token_id",
        "price_eth",
        "transaction_hash"
      ]
    }

  use Lux.Signal, schema_id: __MODULE__
end

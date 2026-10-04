defmodule Lux.Signals.NFT.NFTRaritySignal do
  @moduledoc """
  Signal emitted when collection trait rarity analysis completes.
  """

  use Lux.SignalSchema,
    name: "NFT Rarity Analysis Signal",
    description: "Emitted with collection rarity distributions and token ranks",
    version: "1.0.0",
    compatibility: :full,
    schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        total_supply: %{type: :integer},
        top_rarest_token_id: %{type: :string},
        top_rarity_score: %{type: :number},
        generated_at: %{type: :number}
      },
      required: ["collection_address", "total_supply", "top_rarest_token_id"]
    }

  use Lux.Signal, schema_id: __MODULE__
end

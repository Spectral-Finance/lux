defmodule Lux.Prisms.Nft.RarityScorePrism do
  @moduledoc """
  Calculates trait frequencies and statistical rarity score for an individual NFT.
  """

  use Lux.Prism,
    name: "NFT Rarity Score",
    description: "Evaluates token traits and computes aggregate statistical rarity score",
    input_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer, description: "Token ID"},
        traits: %{type: :array, description: "List of trait attribute objects"},
        total_supply: %{type: :integer, default: 10_000}
      },
      required: ["token_id", "traits"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :integer},
        total_rarity_score: %{type: :number},
        rarity_tier: %{type: :string},
        trait_scores: %{type: :array}
      },
      required: ["token_id", "total_rarity_score", "rarity_tier"]
    }

  alias Lux.Nft.RarityEngine

  def handler(input, _ctx) do
    token_id = Map.get(input, :token_id) || Map.get(input, "token_id", 0)
    traits = Map.get(input, :traits) || Map.get(input, "traits", [])
    supply = Map.get(input, :total_supply) || Map.get(input, "total_supply", 10_000)

    result = RarityEngine.calculate_token_rarity(traits, supply)

    {:ok,
     %{
       token_id: token_id,
       total_rarity_score: result.total_rarity_score,
       rarity_tier: to_string(result.rarity_tier),
       trait_scores: result.trait_scores
     }}
  end
end

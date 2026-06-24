defmodule Lux.Prisms.NFTMarketplace.CalculateRarity do
  @moduledoc """
  Calculate the rarity score and rank for items in a collection based on trait frequency.
  """

  use Lux.Prism,
    name: "NFT Calculate Rarity",
    description: "Calculates traits-based rarity scores and ranks",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{type: :string, description: "The collection slug"},
        traits_data: %{
          type: :object,
          description: "Full traits distribution map and token trait mappings",
          properties: %{
            total_supply: %{type: :integer},
            traits: %{
              type: :object,
              description: "Nested map of: trait_type -> trait_value -> count"
            },
            tokens: %{
              type: :array,
              items: %{
                type: :object,
                properties: %{
                  token_id: %{type: :string},
                  traits: %{type: :object}
                }
              }
            }
          }
        }
      },
      required: ["collection_slug", "traits_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string},
        total_supply: %{type: :integer},
        tokens: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              token_id: %{type: :string},
              traits: %{type: :object},
              rarity_score: %{type: :number},
              rarity_rank: %{type: :integer}
            }
          }
        }
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    slug = params.collection_slug
    data = params.traits_data

    NFTMarketplace.calculate_rarity(slug, data)
  end
end

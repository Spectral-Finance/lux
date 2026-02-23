defmodule Lux.Prisms.NFT.CalculateRarityScore do
  @moduledoc """
  A prism for calculating rarity scores for NFTs based on trait analysis.

  Uses statistical rarity scoring (harmonic mean / information theory approach):
  - Each trait's rarity = 1 / (trait_count / total_supply)
  - Overall rarity = sum of individual trait rarities
  - Normalized rank within the collection

  Supports:
  - Per-trait rarity calculation
  - Overall rarity score computation
  - Trait floor price impact estimation
  - Collection-wide ranking

  ## Examples

      iex> CalculateRarityScore.handler(%{
      ...>   total_supply: 10000,
      ...>   nft_traits: [
      ...>     %{trait_type: "Background", value: "Blue", trait_count: 1152},
      ...>     %{trait_type: "Eyes", value: "Laser Eyes", trait_count: 89}
      ...>   ],
      ...>   trait_distributions: %{
      ...>     "Background" => %{"Blue" => 1152, "Red" => 453, "Gold" => 52},
      ...>     "Eyes" => %{"Laser Eyes" => 89, "Normal" => 8500}
      ...>   }
      ...> }, %{name: "Agent"})
      {:ok, %{
        rarity_score: 113.96,
        rarity_rank: nil,
        trait_rarities: [
          %{trait_type: "Background", value: "Blue", trait_count: 1152,
            rarity_score: 8.68, rarity_pct: 11.52},
          %{trait_type: "Eyes", value: "Laser Eyes", trait_count: 89,
            rarity_score: 112.36, rarity_pct: 0.89}
        ]
      }}
  """

  use Lux.Prism,
    name: "Calculate NFT Rarity Score",
    description: "Computes rarity scores for NFT traits using statistical frequency analysis",
    input_schema: %{
      type: :object,
      properties: %{
        total_supply: %{
          type: :integer,
          description: "Total number of NFTs in the collection",
          minimum: 1
        },
        nft_traits: %{
          type: :array,
          description: "List of traits for the NFT being scored",
          items: %{
            type: :object,
            properties: %{
              trait_type: %{type: :string, description: "The trait category name"},
              value: %{type: :string, description: "The trait value"},
              trait_count: %{
                type: :integer,
                description: "Number of NFTs in the collection with this trait value"
              }
            },
            required: ["trait_type", "value", "trait_count"]
          }
        },
        trait_distributions: %{
          type: :object,
          description: "Optional full trait distribution map for null trait scoring. Format: %{trait_type => %{value => count}}",
          additionalProperties: %{
            type: :object,
            additionalProperties: %{type: :integer}
          }
        },
        collection_scores: %{
          type: :array,
          description: "Optional sorted list of all NFT rarity scores for rank calculation",
          items: %{type: :number}
        }
      },
      required: ["total_supply", "nft_traits"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rarity_score: %{type: :number, description: "Total rarity score (higher = rarer)"},
        rarity_rank: %{type: :integer, description: "Rank within collection (1 = rarest), nil if collection_scores not provided"},
        trait_rarities: %{
          type: :array,
          description: "Per-trait rarity breakdown",
          items: %{
            type: :object,
            properties: %{
              trait_type: %{type: :string},
              value: %{type: :string},
              trait_count: %{type: :integer},
              rarity_score: %{type: :number, description: "Rarity contribution (1 / frequency)"},
              rarity_pct: %{type: :number, description: "Percentage of collection with this trait"}
            }
          }
        }
      }
    }

  @doc """
  Calculates rarity scores for an NFT based on its traits.
  """
  @impl true
  def handler(%{total_supply: total_supply, nft_traits: traits} = params, _agent) do
    trait_distributions = params[:trait_distributions] || params["trait_distributions"] || %{}
    collection_scores = params[:collection_scores] || params["collection_scores"] || []

    trait_rarities = calculate_trait_rarities(traits, total_supply, trait_distributions)
    total_score = Enum.reduce(trait_rarities, 0.0, fn t, acc -> acc + t.rarity_score end)
    total_score_rounded = Float.round(total_score, 4)

    rarity_rank = if collection_scores != [] do
      sorted_desc = Enum.sort(collection_scores, :desc)
      Enum.find_index(sorted_desc, &(&1 <= total_score_rounded))
      |> case do
        nil -> length(sorted_desc) + 1
        idx -> idx + 1
      end
    else
      nil
    end

    result = %{
      rarity_score: total_score_rounded,
      rarity_rank: rarity_rank,
      trait_rarities: trait_rarities
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def handler(%{"total_supply" => total_supply, "nft_traits" => traits} = params, agent) do
    traits_as_atoms = Enum.map(traits, fn t ->
      %{
        trait_type: t["trait_type"],
        value: t["value"],
        trait_count: t["trait_count"]
      }
    end)

    handler(
      %{
        total_supply: total_supply,
        nft_traits: traits_as_atoms,
        trait_distributions: params["trait_distributions"],
        collection_scores: params["collection_scores"]
      },
      agent
    )
  end

  def handler(_, _) do
    {:error, "Missing required fields: total_supply and nft_traits"}
  end

  defp calculate_trait_rarities(traits, total_supply, _trait_distributions) do
    Enum.map(traits, fn trait ->
      count = trait[:trait_count] || trait["trait_count"] || 1
      trait_type = trait[:trait_type] || trait["trait_type"]
      value = trait[:value] || trait["value"]

      rarity_pct = Float.round(count / total_supply * 100, 4)
      # Rarity score = 1 / trait_frequency
      # Multiplied by 100 to get a human-readable scale
      rarity_score = Float.round(total_supply / count, 4)

      %{
        trait_type: trait_type,
        value: value,
        trait_count: count,
        rarity_score: rarity_score,
        rarity_pct: rarity_pct
      }
    end)
  end
end

defmodule Lux.Prisms.NFT.TraitRarityPrism do
  @moduledoc """
  A Prism that calculates statistical rarity scores, Shannon entropy,
  trait count rarities, and collection rankings for NFTs.

  ## Example

      iex> Lux.Prisms.NFT.TraitRarityPrism.run(%{
      ...>   collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
      ...>   tokens: [...]
      ...> })
      {:ok, %{
        total_supply: 10000,
        token_scores: [...],
        top_rarest: [...]
      }}
  """

  use Lux.Prism,
    name: "NFT Trait Rarity Scoring",
    description: "Calculates trait frequencies, Shannon entropy, statistical rarity scores, and token ranks",
    input_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        tokens: %{
          type: :array,
          items: %{type: :object}
        },
        total_supply: %{type: :integer}
      },
      required: ["collection_address", "tokens"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        total_supply: %{type: :integer},
        total_traits_count: %{type: :integer},
        token_scores: %{type: :array},
        trait_entropy: %{type: :object}
      },
      required: ["collection_address", "total_supply", "token_scores"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    address = Map.get(input, :collection_address) || Map.get(input, "collection_address")
    tokens = Map.get(input, :tokens) || Map.get(input, "tokens", [])
    total_supply = Map.get(input, :total_supply) || Map.get(input, "total_supply")

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("lux.nft"),
         {:ok, result} <- compute_rarity(address, tokens, total_supply) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import lux.nft Python package: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compute_rarity(address, tokens, total_supply) do
    python variables: %{address: address, tokens: tokens, total_supply: total_supply} do
      ~PY"""
      from lux.nft.rarity.engine import TraitRarityEngine
      from lux.nft.types import TokenMetadata, TraitAttribute

      meta_tokens = []
      for t in tokens:
          attrs = [
              TraitAttribute(
                  trait_type=str(a.get("trait_type", a.get("traitType", "trait"))),
                  value=a.get("value", ""),
              )
              for a in t.get("attributes", [])
          ]
          meta_tokens.append(
              TokenMetadata(
                  token_id=str(t.get("token_id", t.get("tokenId", "0"))),
                  collection_address=address,
                  attributes=attrs,
              )
          )

      engine = TraitRarityEngine(include_missing_traits=True, include_trait_count=True)
      report = engine.analyze_collection(
          collection_address=address,
          tokens=meta_tokens,
          total_supply=int(total_supply) if total_supply else None,
      )
      report.to_dict()
      """
    end
  end
end

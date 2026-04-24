defmodule Lux.Prisms.Nft.NftRarityCalculatorPrism do
  @moduledoc """
  A prism that calculates trait-based rarity scores for NFT collections.

  Uses the OpenSea trait data to compute statistical rarity for each token
  based on trait frequency analysis.

  ## Example

      iex> Lux.Prisms.Nft.NftRarityCalculatorPrism.run(%{
      ...>   collection_slug: "bored-ape-yacht-club",
      ...>   token_id: "1000"
      ...> })
      {:ok, %{
        "status" => "success",
        "rarity_score" => 245.6,
        "rarity_rank" => 345,
        "traits" => [...]
      }}

  The prism reads API configuration from application config:
  - :opensea_api_key - OpenSea API key
  """

  use Lux.Prism,
    name: "NFT Rarity Calculator",
    description: "Calculates trait-based rarity scores for NFT tokens using statistical frequency analysis",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "OpenSea collection slug"
        },
        collection_address: %{
          type: :string,
          description: "NFT contract address",
          pattern: "^0x[a-fA-F0-9]{40}$"
        },
        token_id: %{
          type: :string,
          description: "Specific token ID to calculate rarity for"
        },
        method: %{
          type: :string,
          description: "Rarity calculation method",
          enum: ["statistical", "trait_norm", "jaccard"],
          default: "statistical"
        }
      },
      required: ["collection_slug", "token_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        token_id: %{type: :string},
        rarity_score: %{type: :number},
        rarity_rank: %{type: :integer},
        total_supply: %{type: :integer},
        traits: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              trait_type: %{type: :string},
              value: %{type: :string},
              count: %{type: :integer},
              percentage: %{type: :number},
              rarity_score: %{type: :number}
            }
          }
        },
        method: %{type: :string}
      },
      required: ["status", "token_id", "rarity_score"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    with {:ok, result} <- calculate_rarity(input) do
      {:ok, result}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_rarity(input) do
    python_result =
      python variables: %{input: input} do
        ~PY"""
        import urllib.request
        import json

        slug = input.get("collection_slug", "")
        address = input.get("collection_address", "")
        token_id = input.get("token_id", "")
        method = input.get("method", "statistical")

        rarity_score = 0
        rarity_rank = 0
        total_supply = 0
        traits = []

        # Fetch token traits from OpenSea
        if slug and token_id:
          url = f"https://api.opensea.io/api/v2/asset/{slug}/{token_id}"
          if address:
            url = f"https://api.opensea.io/api/v2/asset/{address}/{token_id}"
          req = urllib.request.Request(url, headers={"User-Agent": "Lux/1.0"})
          try:
            resp = urllib.request.urlopen(req, timeout=15)
            data = json.loads(resp.read().decode())
            total_supply = data.get("collection", {}).get("stats", {}).get("total_supply", 0) or 1

            for trait in data.get("traits", []):
              trait_type = trait.get("trait_type", "")
              value = str(trait.get("value", ""))
              count = trait.get("trait_count", 1) or 1
              percentage = (count / total_supply * 100) if total_supply > 0 else 0
              trait_rarity = total_supply / count if count > 0 else 0
              traits.append({
                "trait_type": trait_type,
                "value": value,
                "count": count,
                "percentage": round(percentage, 2),
                "rarity_score": round(trait_rarity, 2)
              })
              rarity_score += trait_rarity

            # Estimate rank (lower score = rarer = lower rank number)
            rarity_rank = max(1, int(total_supply - (rarity_score / max(len(traits), 1))))

          except Exception as e:
            return {"error": str(e)}

        result = {
          "status": "success",
          "token_id": token_id,
          "rarity_score": round(rarity_score, 2),
          "rarity_rank": rarity_rank,
          "total_supply": total_supply,
          "traits": traits,
          "method": method
        }

        result
        """
      end

    case python_result do
      %{"error" => error} -> {:error, error}
      result when is_map(result) -> {:ok, result}
    end
  end
end

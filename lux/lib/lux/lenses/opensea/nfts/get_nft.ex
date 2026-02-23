defmodule Lux.Lenses.OpenSea.NFTs.GetNFT do
  @moduledoc """
  A lens for retrieving a single NFT by chain, contract, and token ID from OpenSea API v2.

  This lens provides:
  - Full NFT metadata (name, description, image)
  - Complete trait/attribute list for rarity scoring
  - Current owner and creator info
  - Last sale price
  - OpenSea rarity rank

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> GetNFT.focus(%{
      ...>   chain: "ethereum",
      ...>   address: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
      ...>   identifier: "1"
      ...> })
      {:ok, %{
        identifier: "1",
        collection: "boredapeyachtclub",
        contract: "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
        name: "Bored Ape #1",
        rarity_rank: 2491,
        traits: [%{trait_type: "Background", value: "Blue"}],
        owners: [%{address: "0x...", quantity: 1}]
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "Get NFT",
    description: "Retrieves a single NFT with traits, ownership, and rarity data from OpenSea",
    url: "https://api.opensea.io/api/v2/chain/:chain/contract/:address/nfts/:identifier",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "The blockchain chain (e.g., 'ethereum', 'matic', 'base')",
          enum: ["ethereum", "matic", "klaytn", "base", "blast", "arbitrum", "optimism",
                 "avalanche", "bsc", "zora", "solana", "apecoin", "ancient8", "apex",
                 "b3", "baobab", "boss", "forma", "gunzilla", "hychain", "manta",
                 "mantle", "mode", "moonbeam", "mumbai", "rari", "scroll", "sei",
                 "shape", "unichain", "viction", "xai", "zkatana"]
        },
        address: %{
          type: :string,
          description: "The contract address of the NFT",
          pattern: "^0x[0-9a-fA-F]{40}$"
        },
        identifier: %{
          type: :string,
          description: "The token ID of the NFT"
        }
      },
      required: ["chain", "address", "identifier"]
    }

  @doc """
  Transforms the OpenSea API response into a simplified format.
  """
  @impl true
  def after_focus(%{"nft" => nft}) do
    result = %{
      identifier: nft["identifier"],
      collection: nft["collection"],
      contract: nft["contract"],
      token_standard: nft["token_standard"],
      name: nft["name"],
      description: nft["description"],
      image_url: nft["image_url"],
      display_image_url: nft["display_image_url"],
      metadata_url: nft["metadata_url"],
      opensea_url: nft["opensea_url"],
      updated_at: nft["updated_at"],
      is_disabled: nft["is_disabled"],
      is_nsfw: nft["is_nsfw"],
      animation_url: nft["animation_url"],
      is_suspicious: nft["is_suspicious"],
      creator: nft["creator"],
      traits: transform_traits(nft["traits"] || []),
      owners: transform_owners(nft["owners"] || []),
      rarity_rank: get_in(nft, ["rarity", "rank"]),
      rarity_strategy_id: get_in(nft, ["rarity", "strategy_id"])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()

    {:ok, result}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_traits(traits) do
    Enum.map(traits, fn trait ->
      %{
        trait_type: trait["trait_type"],
        value: trait["value"],
        display_type: trait["display_type"],
        max_value: trait["max_value"],
        trait_count: trait["trait_count"],
        order: trait["order"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    end)
  end

  defp transform_owners(owners) do
    Enum.map(owners, fn owner ->
      %{
        address: owner["address"],
        quantity: owner["quantity"]
      }
    end)
  end
end

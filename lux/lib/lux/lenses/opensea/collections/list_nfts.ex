defmodule Lux.Lenses.OpenSea.Collections.ListNFTs do
  @moduledoc """
  A lens for listing NFTs in a collection from the OpenSea API v2.

  This lens provides paginated access to NFTs in a collection with:
  - Token identifiers and metadata
  - Trait/attribute data for rarity analysis
  - Current ownership information
  - Last sale price
  - Pagination support via cursor

  ## Authentication

  Uses optional API key via `x-api-key` header. Configure in application config:

      config :lux, :api_keys, opensea: "your_api_key"

  ## Examples

      iex> ListNFTs.focus(%{
      ...>   collection_slug: "boredapeyachtclub",
      ...>   limit: 20
      ...> })
      {:ok, %{
        nfts: [
          %{
            identifier: "1",
            name: "Bored Ape #1",
            image_url: "https://...",
            traits: [%{trait_type: "Background", value: "Blue", trait_count: 1152}]
          }
        ],
        next_cursor: "abc123"
      }}
  """

  alias Lux.Integrations.OpenSea

  use Lux.Lens,
    name: "List NFTs in Collection",
    description: "Lists NFTs in a collection with traits for rarity analysis",
    url: "https://api.opensea.io/api/v2/collection/:collection_slug/nfts",
    method: :get,
    headers: OpenSea.headers(),
    auth: OpenSea.auth(),
    schema: %{
      type: :object,
      properties: %{
        collection_slug: %{
          type: :string,
          description: "The unique identifier (slug) for the collection",
          pattern: "^[a-z0-9-]+$"
        },
        limit: %{
          type: :integer,
          description: "Number of NFTs to return (1-200, default 20)",
          minimum: 1,
          maximum: 200,
          default: 20
        },
        next: %{
          type: :string,
          description: "Cursor for pagination (from previous response's next_cursor)"
        }
      },
      required: ["collection_slug"]
    }

  @doc """
  Transforms the OpenSea API response into a simplified format.
  """
  @impl true
  def after_focus(%{"nfts" => nfts} = data) do
    transformed_nfts = Enum.map(nfts, &transform_nft/1)
    {:ok, %{nfts: transformed_nfts, next_cursor: data["next"]}}
  end

  def after_focus(%{"detail" => detail}) do
    {:error, %{detail: detail}}
  end

  def after_focus(response) do
    {:error, %{title: "Unexpected response", detail: inspect(response)}}
  end

  defp transform_nft(nft) do
    %{
      identifier: nft["identifier"],
      name: nft["name"],
      description: nft["description"],
      image_url: nft["image_url"],
      metadata_url: nft["metadata_url"],
      opensea_url: nft["opensea_url"],
      updated_at: nft["updated_at"],
      is_suspicious: nft["is_suspicious"],
      rarity_rank: get_in(nft, ["rarity", "rank"]),
      rarity_strategy_id: get_in(nft, ["rarity", "strategy_id"]),
      traits: transform_traits(nft["traits"] || [])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
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
end

defmodule Lux.Prisms.NFTMarketplace.GetListings do
  @moduledoc """
  Retrieve active listings for a collection.
  """

  use Lux.Prism,
    name: "NFT Get Listings",
    description: "Retrieves active listings from OpenSea, Blur, or X2Y2",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{type: :string, description: "The collection slug"},
        marketplace: %{
          type: :string,
          enum: ["opensea", "blur", "x2y2"],
          default: "opensea",
          description: "Marketplace to query"
        }
      },
      required: ["collection_slug"]
    },
    output_schema: %{
      type: :array,
      items: %{
        type: :object,
        properties: %{
          token_id: %{type: :string},
          price: %{type: :number},
          payment_token: %{type: :string},
          seller: %{type: :string},
          marketplace: %{type: :string}
        }
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    slug = Map.get(params, "collection_slug") || Map.get(params, :collection_slug)
    mkt = Map.get(params, "marketplace") || Map.get(params, :marketplace) || "opensea"

    if is_nil(slug) or slug == "" do
      {:error, "Missing required parameter: collection_slug"}
    else
      case NFTMarketplace.get_listings(slug, mkt) do
        {:ok, listings} -> {:ok, listings}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end

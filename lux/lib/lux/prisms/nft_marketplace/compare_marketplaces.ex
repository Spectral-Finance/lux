defmodule Lux.Prisms.NFTMarketplace.CompareMarketplaces do
  @moduledoc """
  Compare floor price, volume, and statistics across OpenSea, Blur, and X2Y2.
  """

  use Lux.Prism,
    name: "NFT Compare Marketplaces",
    description: "Compares collection stats and finds best place to buy or sell",
    input_schema: %{
      type: :object,
      properties: %{
        collection_slug: %{type: :string, description: "The collection slug"}
      },
      required: ["collection_slug"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string},
        best_buy: %{type: :string},
        best_sell: %{type: :string},
        marketplaces: %{type: :object}
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    slug = Map.get(params, "collection_slug") || Map.get(params, :collection_slug)

    if is_nil(slug) or slug == "" do
      {:error, "Missing required parameter: collection_slug"}
    else
      NFTMarketplace.compare_marketplaces(slug)
    end
  end
end

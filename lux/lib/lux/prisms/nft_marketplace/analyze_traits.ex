defmodule Lux.Prisms.NFTMarketplace.AnalyzeTraits do
  @moduledoc """
  Analyze trait distribution and floor prices per trait.
  """

  use Lux.Prism,
    name: "NFT Analyze Traits",
    description: "Analyzes trait scarcity and values in a collection",
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
      type: :object,
      properties: %{
        collection: %{type: :string},
        traits: %{type: :object}
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    slug = Map.get(params, "collection_slug") || Map.get(params, :collection_slug)
    mkt = Map.get(params, "marketplace") || Map.get(params, :marketplace) || "opensea"

    if is_nil(slug) or slug == "" do
      {:error, "Missing required parameter: collection_slug"}
    else
      NFTMarketplace.analyze_traits(slug, mkt)
    end
  end
end

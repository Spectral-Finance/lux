defmodule Lux.Prisms.NFTMarketplace.MonitorSales do
  @moduledoc """
  Monitor recent sales events for a given NFT collection.
  """

  use Lux.Prism,
    name: "NFT Monitor Sales",
    description: "Retrieves recent sales from OpenSea, Blur, or X2Y2",
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
          buyer: %{type: :string},
          seller: %{type: :string},
          timestamp: %{type: :integer},
          marketplace: %{type: :string}
        }
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(params, _agent) do
    slug = params.collection_slug
    mkt = String.to_existing_atom(Map.get(params, :marketplace, "opensea"))

    case NFTMarketplace.get_sales(slug, mkt) do
      {:ok, sales} -> {:ok, sales}
      {:error, reason} -> {:error, reason}
    end
  end
end

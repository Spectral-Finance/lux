defmodule Lux.Prisms.Nft.CollectionStatsPrism do
  @moduledoc """
  Normalizes collection metrics across NFT marketplaces.
  """

  use Lux.Prism,
    name: "NFT Collection Stats",
    description: "Extracts floor price, volume, supply, and owner count for an NFT collection",
    input_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string, description: "Collection slug or contract address"},
        stats_data: %{type: :object, description: "Raw marketplace API stats payload"},
        marketplace: %{type: :string, default: "opensea"}
      },
      required: ["collection", "stats_data"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string},
        floor_price_eth: %{type: :number},
        volume_24h_eth: %{type: :number},
        total_supply: %{type: :integer},
        num_owners: %{type: :integer},
        marketplace: %{type: :string}
      },
      required: ["collection", "floor_price_eth", "total_supply"]
    }

  alias Lux.Nft.MarketplaceClient

  def handler(input, _ctx) do
    col = Map.get(input, :collection) || Map.get(input, "collection", "unknown")
    data = Map.get(input, :stats_data) || Map.get(input, "stats_data", %{})
    market_str = Map.get(input, :marketplace) || Map.get(input, "marketplace", "opensea")
    market = market_str |> String.downcase() |> String.to_atom()

    stats = MarketplaceClient.normalize_stats(data, market)

    {:ok,
     Map.merge(stats, %{
       collection: col,
       marketplace: to_string(stats.marketplace)
     })}
  end
end

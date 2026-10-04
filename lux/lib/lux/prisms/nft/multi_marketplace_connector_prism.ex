defmodule Lux.Prisms.NFT.MultiMarketplaceConnectorPrism do
  @moduledoc """
  A Prism that aggregates NFT collection floor prices and volume stats
  across OpenSea, Blur, and LooksRare venues.

  ## Example

      iex> Lux.Prisms.NFT.MultiMarketplaceConnectorPrism.run(%{
      ...>   collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"
      ...> })
      {:ok, %{
        best_floor_price_eth: 12.45,
        best_marketplace: "blur",
        spread_eth: 0.15,
        spread_percent: 1.20,
        quotes: %{...}
      }}
  """

  use Lux.Prism,
    name: "Multi-Marketplace NFT Aggregator",
    description: "Fetches and aggregates real-time floor prices and stats across OpenSea, Blur, and LooksRare",
    input_schema: %{
      type: :object,
      properties: %{
        collection_address: %{
          type: :string,
          description: "NFT Contract Address (0x...)"
        }
      },
      required: ["collection_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        best_floor_price_eth: %{type: :number},
        best_floor_price_usd: %{type: :number},
        best_marketplace: %{type: :string},
        spread_eth: %{type: :number},
        spread_percent: %{type: :number},
        quotes: %{type: :object}
      },
      required: ["collection_address", "best_floor_price_eth", "best_marketplace"]
    }

  import Lux.Python

  require Lux.Python

  def handler(%{collection_address: address} = _input, _ctx) do
    with {:ok, %{"success" => true}} <- Lux.Python.import_package("lux.nft"),
         {:ok, result} <- fetch_aggregated_data(address) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import lux.nft Python package: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(%{"collection_address" => address} = input, ctx) do
    handler(%{collection_address: address}, ctx)
  end

  defp fetch_aggregated_data(address) do
    python variables: %{address: address} do
      ~PY"""
      from lux.nft.connectors.aggregator import MultiMarketplaceAggregator
      agg = MultiMarketplaceAggregator()
      floor_data = agg.get_aggregated_floor_price(address)
      floor_data.to_dict()
      """
    end
  end
end

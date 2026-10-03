defmodule Lux.Prisms.NFT.SalesStreamPollerPrism do
  @moduledoc """
  A Prism that polls and deduplicates normalized sales events across NFT venues.

  ## Example

      iex> Lux.Prisms.NFT.SalesStreamPollerPrism.run(%{
      ...>   collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
      ...>   min_price_eth: 5.0,
      ...>   limit: 20
      ...> })
      {:ok, %{
        sales: [...],
        count: 15
      }}
  """

  use Lux.Prism,
    name: "NFT Sales Stream Poller",
    description: "Fetches, deduplicates, and normalizes recent sales across multi-marketplace feeds",
    input_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        min_price_eth: %{type: :number},
        max_price_eth: %{type: :number},
        whale_threshold_eth: %{type: :number},
        limit: %{type: :integer, default: 30}
      },
      required: ["collection_address"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        sales: %{
          type: :array,
          items: %{type: :object}
        },
        count: %{type: :integer}
      },
      required: ["collection_address", "sales", "count"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    address = Map.get(input, :collection_address) || Map.get(input, "collection_address")
    min_price = Map.get(input, :min_price_eth) || Map.get(input, "min_price_eth")
    max_price = Map.get(input, :max_price_eth) || Map.get(input, "max_price_eth")
    whale_threshold = Map.get(input, :whale_threshold_eth) || Map.get(input, "whale_threshold_eth", 10.0)
    limit = Map.get(input, :limit) || Map.get(input, "limit", 30)

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("lux.nft"),
         {:ok, result} <- poll_sales(address, min_price, max_price, whale_threshold, limit) do
      {:ok, %{collection_address: address, sales: result, count: length(result)}}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import lux.nft Python package: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp poll_sales(address, min_price, max_price, whale_threshold, limit) do
    python variables: %{
             address: address,
             min_price: min_price,
             max_price: max_price,
             whale_threshold: whale_threshold,
             limit: limit
           } do
      ~PY"""
      from lux.nft.sales.poller import SalesStreamPoller, EventFilterConfig
      filter_cfg = EventFilterConfig(
          min_price_eth=float(min_price) if min_price is not None else None,
          max_price_eth=float(max_price) if max_price is not None else None,
          whale_threshold_eth=float(whale_threshold),
      )
      poller = SalesStreamPoller(filter_config=filter_cfg)
      sales = poller.poll_once(address, limit_per_venue=int(limit))
      [s.to_dict() for s in sales]
      """
    end
  end
end

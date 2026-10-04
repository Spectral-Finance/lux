defmodule Lux.Lenses.NFT.FloorPriceLens do
  @moduledoc """
  Lens for querying multi-marketplace NFT floor prices.

  ## Example

      alias Lux.Lenses.NFT.FloorPriceLens

      # Fetch floor price for Bored Ape Yacht Club
      FloorPriceLens.focus(%{
        collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
        marketplace: "opensea"
      })
  """

  use Lux.Lens,
    name: "NFT Floor Price Lens",
    description: "Fetches collection floor price quotes across NFT marketplaces",
    url: "https://api.opensea.io/api/v2/collections",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        collection_address: %{
          type: :string,
          description: "Contract address or collection slug"
        },
        marketplace: %{
          type: :string,
          description: "Marketplace venue (opensea, blur, looksrare)",
          enum: ["opensea", "blur", "looksrare"],
          default: "opensea"
        }
      },
      required: ["collection_address"]
    }

  @impl true
  def after_focus(%{"total" => %{"floor_price" => floor}} = body) do
    {:ok,
     %{
       marketplace: "opensea",
       floor_price_eth: floor,
       floor_price_usd: Map.get(body["total"], "floor_price_usd", floor * 3000.0),
       raw_data: body
     }}
  end

  def after_focus(%{"data" => %{"floorPrice" => floor_wei}} = body) do
    floor_eth = String.to_integer(floor_wei) / 1.0e18

    {:ok,
     %{
       marketplace: "looksrare",
       floor_price_eth: floor_eth,
       floor_price_usd: floor_eth * 3000.0,
       raw_data: body
     }}
  end

  def after_focus(%{"error" => error}) do
    {:error, error}
  end

  def after_focus(other) do
    {:ok, other}
  end
end

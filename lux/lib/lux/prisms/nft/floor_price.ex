defmodule Lux.Prisms.Nft.FloorPricePrism do
  @moduledoc """
  Compares floor prices across major NFT marketplaces (OpenSea, Blur, LooksRare).
  """

  use Lux.Prism,
    name: "NFT Floor Price Comparison",
    description: "Evaluates lowest available floor price across OpenSea, Blur, and LooksRare",
    input_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string, description: "Collection identifier"},
        opensea_floor: %{type: :number},
        blur_floor: %{type: :number},
        looksrare_floor: %{type: :number}
      },
      required: ["collection"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection: %{type: :string},
        lowest_floor_eth: %{type: :number},
        best_marketplace: %{type: :string},
        floors: %{type: :object}
      },
      required: ["collection", "lowest_floor_eth", "best_marketplace"]
    }

  def handler(input, _ctx) do
    col = Map.get(input, :collection) || Map.get(input, "collection", "unknown")
    os_floor = Map.get(input, :opensea_floor) || Map.get(input, "opensea_floor")
    blur_floor = Map.get(input, :blur_floor) || Map.get(input, "blur_floor")
    lr_floor = Map.get(input, :looksrare_floor) || Map.get(input, "looksrare_floor")

    floors =
      [
        {"opensea", os_floor},
        {"blur", blur_floor},
        {"looksrare", lr_floor}
      ]
      |> Enum.filter(fn {_m, p} -> not is_nil(p) and p > 0.0 end)

    {best_market, lowest_p} =
      case floors do
        [] -> {"none", 0.0}
        list -> Enum.min_by(list, fn {_m, p} -> p end)
      end

    {:ok,
     %{
       collection: col,
       lowest_floor_eth: lowest_p * 1.0,
       best_marketplace: best_market,
       floors: Map.new(floors)
     }}
  end
end

defmodule Lux.Prisms.NFT.PriceTrackingPrism do
  @moduledoc """
  A Prism that tracks NFT price dynamics, volume, 24h percentage deltas,
  moving averages, VWAP, and market trend directions.

  ## Example

      iex> Lux.Prisms.NFT.PriceTrackingPrism.run(%{
      ...>   collection_address: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
      ...>   current_floor_eth: 12.5,
      ...>   sales: [...]
      ...> })
      {:ok, %{
        trend_direction: "BULLISH",
        price_change_24h_percent: 5.2,
        vwap_24h_eth: 12.8,
        moving_averages: %{sma_7: 12.3, sma_24: 11.9}
      }}
  """

  use Lux.Prism,
    name: "NFT Price Tracking & Trend Analytics",
    description: "Calculates volume, 24h delta, moving averages, VWAP, and trend directions",
    input_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        current_floor_eth: %{type: :number},
        sales: %{
          type: :array,
          items: %{type: :object}
        },
        floor_history_hourly: %{
          type: :array,
          items: %{type: :number}
        }
      },
      required: ["collection_address", "current_floor_eth"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        collection_address: %{type: :string},
        current_floor_eth: %{type: :number},
        price_change_24h_percent: %{type: :number},
        volume_24h_eth: %{type: :number},
        volume_change_24h_percent: %{type: :number},
        vwap_24h_eth: %{type: :number},
        trend_direction: %{type: :string},
        liquidity_index: %{type: :number}
      },
      required: ["collection_address", "current_floor_eth", "trend_direction"]
    }

  import Lux.Python

  require Lux.Python

  def handler(input, _ctx) do
    address = Map.get(input, :collection_address) || Map.get(input, "collection_address")
    floor = Map.get(input, :current_floor_eth) || Map.get(input, "current_floor_eth", 0.0)
    sales = Map.get(input, :sales) || Map.get(input, "sales", [])
    history = Map.get(input, :floor_history_hourly) || Map.get(input, "floor_history_hourly", [])

    with {:ok, %{"success" => true}} <- Lux.Python.import_package("lux.nft"),
         {:ok, result} <- analyze_trends(address, floor, sales, history) do
      {:ok, result}
    else
      {:ok, %{"success" => false, "error" => error}} ->
        {:error, "Failed to import lux.nft Python package: #{error}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_trends(address, floor, sales, history) do
    python variables: %{address: address, floor: floor, sales: sales, history: history} do
      ~PY"""
      from lux.nft.pricing.engine import PriceTrackingEngine
      from lux.nft.sales.normalizer import SalesEventNormalizer

      normalizer = SalesEventNormalizer()
      normalized_sales = [normalizer.normalize(s) if isinstance(s, dict) else s for s in sales]

      engine = PriceTrackingEngine()
      analysis = engine.analyze_price_trends(
          collection_address=address,
          current_floor_eth=float(floor),
          historical_sales=normalized_sales,
          floor_history_hourly=history or None,
      )
      analysis.to_dict()
      """
    end
  end
end

defmodule Lux.Prisms.Nft.SalesTrackerPrism do
  @moduledoc """
  Monitors NFT sales, filters wash trading, and calculates authentic volume.
  """

  use Lux.Prism,
    name: "NFT Sales Tracker",
    description: "Filters suspicious wash trades and calculates clean sales volume",
    input_schema: %{
      type: :object,
      properties: %{
        sales: %{type: :array, description: "List of raw sales records"}
      },
      required: ["sales"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        clean_sales_count: %{type: :integer},
        flagged_wash_trades_count: %{type: :integer},
        clean_volume_eth: %{type: :number},
        wash_trading_pct: %{type: :number}
      },
      required: ["clean_sales_count", "clean_volume_eth", "wash_trading_pct"]
    }

  alias Lux.Nft.SalesMonitor

  def handler(input, _ctx) do
    sales = Map.get(input, :sales) || Map.get(input, "sales", [])
    result = SalesMonitor.filter_wash_trades(sales)

    {:ok,
     %{
       clean_sales_count: length(result.clean_sales),
       flagged_wash_trades_count: length(result.flagged_sales),
       clean_volume_eth: result.clean_volume_eth,
       wash_trading_pct: result.wash_trading_pct
     }}
  end
end

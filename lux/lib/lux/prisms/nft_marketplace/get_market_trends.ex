defmodule Lux.Prisms.NFTMarketplace.GetMarketTrends do
  @moduledoc """
  Retrieve global NFT market volume, trends, and top gainers.
  """

  use Lux.Prism,
    name: "NFT Get Market Trends",
    description: "Retrieves global NFT market statistics and top gainers",
    input_schema: %{
      type: :object,
      properties: %{}
    },
    output_schema: %{
      type: :object,
      properties: %{
        timeframe: %{type: :string},
        total_volume_eth: %{type: :number},
        total_sales_count: %{type: :integer},
        market_cap_eth: %{type: :number},
        top_gainers: %{type: :array},
        market_sentiment: %{type: :string}
      }
    }

  alias Lux.Integrations.NFTMarketplace

  def handler(_params, _agent) do
    NFTMarketplace.get_market_trends()
  end
end

defmodule Lux.Prisms.NFT.MarketplaceAggregationPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.NFT.MarketplaceAggregationPrism

  test "returns an NFT marketplace aggregation report" do
    assert {:ok, report} =
             MarketplaceAggregationPrism.handler(
               %{
                 collection_slug: "azuki",
                 marketplaces: [
                   %{
                     marketplace: "opensea",
                     stats: %{floor_price: 4.5, volume_24h: 100.0},
                     listings: [%{token_id: "1", price: 4.5}],
                     sales: [%{token_id: "1", price: 4.7}],
                     tokens: [%{token_id: "1", traits: %{"Background" => "Red"}}]
                   }
                 ]
               },
               %{agent: %{name: "NFTAgent"}}
             )

    assert report.collection_data.marketplaces == 1
    assert report.price_tracking.lowest_floor.marketplace == "opensea"
    assert report.sales_monitoring.sales_count == 1
    assert report.rarity.tokens != []
    assert :cross_marketplace_comparison in report.coverage
  end

  test "exposes prism schema" do
    view = MarketplaceAggregationPrism.view()

    assert view.name == "NFT Marketplace Aggregation"
    assert Map.has_key?(view.input_schema.properties, :collection_slug)
    assert "collection_data" in view.output_schema.required
  end
end

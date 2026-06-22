defmodule Lux.Integration.Lenses.NftMarketplaceTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.{NftCollectionStatsLens, NftSalesLens, NftMarketTrendsLens, NftRarityLens}
  alias Lux.Prisms.NftMarketplaceDataPrism

  @moduletag :integration

  setup do
    # Using BAYC as an example collection
    %{collection: "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"}
  end

  @tag :external
  test "fetches collection stats", %{collection: collection} do
    assert {:ok, %{collection_stats: stats}} = NftCollectionStatsLens.focus(%{collection: collection})
    
    assert stats.name != nil
    assert stats.floor_price != nil
    assert stats.token_count > 0
  end

  @tag :external
  test "fetches recent sales", %{collection: collection} do
    assert {:ok, %{sales: sales}} = NftSalesLens.focus(%{collection: collection, limit: 5})
    
    assert length(sales) <= 5
    assert Enum.all?(sales, fn sale -> sale.price_eth != nil end)
  end

  @tag :external
  test "fetches market trends", %{collection: collection} do
    assert {:ok, %{trends: trends}} = NftMarketTrendsLens.focus(%{collection: collection, limit: 7})
    
    assert length(trends) <= 7
    assert Enum.all?(trends, fn trend -> trend.volume != nil end)
  end

  @tag :external
  test "fetches token rarity and traits", %{collection: collection} do
    assert {:ok, %{tokens: tokens}} = NftRarityLens.focus(%{collection: collection, limit: 5})
    
    assert length(tokens) <= 5
    assert Enum.all?(tokens, fn t -> t.token_id != nil end)
  end

  @tag :external
  test "prism aggregates all data", %{collection: collection} do
    assert {:ok, result} = NftMarketplaceDataPrism.run(%{collection: collection})

    assert %{
      stats: %{},
      recent_sales: sales,
      trends: trends,
      rarity_analysis: rarity
    } = result

    assert sales != []
    assert trends != []
    assert rarity != []
  end
end

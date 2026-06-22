defmodule Lux.Lenses.NftMarketplaceTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Reservoir.{CollectionStatsLens, SalesLens, MarketTrendsLens, RarityLens}
  alias Lux.Prisms.NftMarketplaceDataPrism

  @moduletag :integration

  # Using a known NFT collection address (e.g. Bored Ape Yacht Club or Azuki)
  # BAYC: 0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d
  @collection "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"

  describe "NFT Marketplace Data Aggregation Lenses" do
    test "CollectionStatsLens fetches stats successfully" do
      result = CollectionStatsLens.focus(%{collection: @collection})
      assert {:ok, %{collection_stats: stats}} = result
      assert stats.id != nil
      assert stats.name != nil
    end

    test "SalesLens fetches recent sales successfully" do
      result = SalesLens.focus(%{collection: @collection, limit: 5})
      assert {:ok, %{sales: sales}} = result
      assert is_list(sales)
    end

    test "MarketTrendsLens fetches volume trends successfully" do
      result = MarketTrendsLens.focus(%{collection: @collection, limit: 7})
      assert {:ok, %{trends: trends}} = result
      assert is_list(trends)
    end

    test "RarityLens fetches token rarity analysis successfully" do
      result = RarityLens.focus(%{collection: @collection, limit: 5})
      assert {:ok, %{tokens: tokens}} = result
      assert is_list(tokens)
    end
  end

  describe "NftMarketplaceDataPrism" do
    test "aggregates data from all lenses" do
      result = NftMarketplaceDataPrism.run(%{collection: @collection})
      assert {:ok, aggregated_data} = result
      assert aggregated_data.stats.id != nil
      assert is_list(aggregated_data.recent_sales)
      assert is_list(aggregated_data.trends)
      assert is_list(aggregated_data.rarity_analysis)
    end
  end
end

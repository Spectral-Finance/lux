defmodule Lux.Integrations.NFTMarketplaceTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.NFTMarketplace

  describe "floor price tracking" do
    test "get_floor_prices returns floor data across marketplaces" do
      result = NFTMarketplace.get_floor_prices("bored-ape-yacht-club")
      assert {:ok, floor} = result
      assert Map.has_key?(floor, :collection_slug)
      assert Map.has_key?(floor, :best_floor_eth)
      assert Map.has_key?(floor, :marketplaces)
      assert Map.has_key?(floor, :floor_spread)
      assert Map.has_key?(floor, :marketplaces, :opensea)
    end

    test "get_floor_prices with specific marketplaces" do
      result = NFTMarketplace.get_floor_prices("bored-ape-yacht-club", marketplaces: [:blur, :looksrare])
      assert {:ok, floor} = result
      assert Map.has_key?(floor.marketplaces, :blur)
      assert Map.has_key?(floor.marketplaces, :looksrare)
    end

    test "query_marketplace_floor handles unknown marketplace" do
      assert {:error, _} = NFTMarketplace.query_marketplace_floor(:unknown, "test")
    end
  end

  describe "collection analytics" do
    test "get_collection_analytics returns analytics" do
      result = NFTMarketplace.get_collection_analytics("bored-ape-yacht-club")
      assert {:ok, analytics} = result
      assert Map.has_key?(analytics, :total_items)
      assert Map.has_key?(analytics, :total_owners)
      assert Map.has_key?(analytics, :volume_24h_eth)
      assert Map.has_key?(analytics, :unique_owners_pct)
      assert Map.has_key?(analytics, :estimated_mcap)
      assert Map.has_key?(analytics, :floor)
    end
  end

  describe "floor history tracking" do
    test "track_floor_history returns history" do
      result = NFTMarketplace.track_floor_history("bored-ape-yacht-club", 7)
      assert {:ok, history} = result
      assert Map.has_key?(history, :history)
      assert Map.has_key?(history, :price_min)
      assert Map.has_key?(history, :price_max)
      assert Map.has_key?(history, :price_avg)
      assert Map.has_key?(history, :volatility)
      assert length(history.history) == 7
    end

    test "track_floor_history with custom days" do
      result = NFTMarketplace.track_floor_history("bored-ape-yacht-club", 30)
      assert {:ok, history} = result
      assert length(history.history) == 30
    end
  end

  describe "listing aggregation" do
    test "aggregate_listings returns sorted listings" do
      result = NFTMarketplace.aggregate_listings("bored-ape-yacht-club",
        marketplaces: [:opensea, :blur],
        max_results: 10
      )
      assert {:ok, agg} = result
      assert Map.has_key?(agg, :total_listings)
      assert Map.has_key?(agg, :listings)
      assert Map.has_key?(agg, :cheapest)
      assert Map.has_key?(agg, :floor_price)
    end
  end

  describe "portfolio valuation" do
    test "calculate_portfolio_value returns valuations" do
      nfts = [{"0xcontract1", "1"}, {"0xcontract2", "2"}]
      result = NFTMarketplace.calculate_portfolio_value(nfts)
      assert {:ok, portfolio} = result
      assert Map.has_key?(portfolio, :assets)
      assert Map.has_key?(portfolio, :total_estimated_value_eth)
      assert portfolio.asset_count == 2
    end
  end

  describe "marketplace queries" do
    test "query_marketplace_floor works for all known marketplaces" do
      for marketplace <- [:opensea, :blur, :looksrare, :x2y2, :rarible, :magic_eden] do
        result = NFTMarketplace.query_marketplace_floor(marketplace, "test-collection")
        assert elem(result, 0) == :ok, "Failed for #{marketplace}"
      end
    end
  end
end

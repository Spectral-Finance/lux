defmodule Lux.Integrations.Nft.MarketplaceTest do
  use UnitCase, async: true

  alias Lux.Integrations.Nft.Marketplace

  describe "collection_stats/1" do
    test "aggregates collection statistics across marketplaces" do
      stats =
        Marketplace.collection_stats([
          %{
            marketplace: "OpenSea",
            slug: "azuki",
            floor_price: "4.2",
            volume: "1200.5",
            owners: "4300",
            supply: 10_000
          },
          %{
            marketplace: :blur,
            slug: "azuki",
            floor: 4.0,
            total_volume: 950,
            owner_count: 4_100,
            total_supply: 10_000
          }
        ])

      assert stats.marketplaces == ["opensea", "blur"]
      assert stats.collection_count == 2
      assert stats.floor_price == 4.0
      assert stats.total_volume == 2150.5
      assert stats.total_owners == 8400
      assert stats.total_supply == 10_000
      assert stats.by_marketplace["opensea"].slug == "azuki"
    end

    test "handles an empty collection list" do
      assert Marketplace.collection_stats([]) == %{
               marketplaces: [],
               collection_count: 0,
               floor_price: 0.0,
               total_volume: 0.0,
               total_owners: 0,
               total_supply: 0,
               by_marketplace: %{}
             }
    end
  end

  describe "price_tracking/1" do
    test "normalizes active listings and tracks floor prices" do
      tracking =
        Marketplace.price_tracking([
          %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: "4.2", currency: "eth"},
          %{marketplace: "Blur", collection: "azuki", token_id: 2, price: 4.0},
          %{marketplace: "X2Y2", collection: "azuki", token_id: 3, price: 4.8},
          %{marketplace: "OpenSea", collection: "azuki", token_id: 4, price: 3.9, status: "cancelled"}
        ])

      assert tracking.listing_count == 3
      assert tracking.floor_price == 4.0
      assert tracking.average_price == 4.333333
      assert tracking.median_price == 4.2
      assert tracking.cheapest_listing.marketplace == "blur"
      assert tracking.by_marketplace["opensea"].floor_price == 4.2
    end

    test "ignores inactive and invalid listing prices deterministically" do
      tracking =
        Marketplace.price_tracking([
          %{"marketplace" => "OpenSea", "collection" => "azuki", "token_id" => 1, "price" => "0"},
          %{marketplace: "OPENSEA", collection: "azuki", token_id: 1, price: "-1"},
          %{marketplace: "Blur", collection: "azuki", token_id: 2, amount: "not-a-number"},
          %{marketplace: "Blur", collection: "azuki", token_id: 3, price: 3.8, status: "cancelled"},
          %{marketplace: "OpenSea", collection: "azuki", token_id: 4, price: "4.1", status: "ACTIVE"},
          %{marketplace: "opensea", collection: "azuki", token_id: 4, amount: 4.2}
        ])

      assert tracking.listing_count == 2
      assert tracking.floor_price == 4.1
      assert tracking.average_price == 4.15
      assert tracking.cheapest_listing.token_id == "4"
      assert Enum.map(tracking.listings, & &1.price) == [4.1, 4.2]
      assert Map.keys(tracking.by_marketplace) == ["opensea"]
    end

    test "returns empty summaries when there are no active listings" do
      tracking =
        Marketplace.price_tracking([
          %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 0},
          %{marketplace: "Blur", collection: "azuki", token_id: 2, price: 4.0, status: "inactive"}
        ])

      assert tracking.listing_count == 0
      assert tracking.floor_price == 0.0
      assert tracking.average_price == 0.0
      assert tracking.median_price == 0.0
      assert tracking.cheapest_listing == nil
      assert tracking.listings == []
      assert tracking.by_marketplace == %{}
    end
  end

  describe "sales_monitor/2" do
    test "filters sales by collection and price" do
      monitor =
        Marketplace.sales_monitor(sample_sales(), %{
          collection: "azuki",
          min_price: 4.0,
          since: "2026-05-12T00:00:00Z"
        })

      assert monitor.sale_count == 2
      assert monitor.total_volume == 9.5
      assert monitor.average_sale_price == 4.75
      assert monitor.highest_sale.token_id == "3"
      assert Enum.map(monitor.sales, & &1.token_id) == ["3", "2"]
    end

    test "keeps missing timestamps deterministic and supports marketplace casing filters" do
      monitor =
        Marketplace.sales_monitor(
          [
            %{"marketplace" => "OPENSEA", "collection" => "azuki", "id" => 1, "amount" => "4.2"},
            %{marketplace: "opensea", collection: "azuki", token_id: 2, price: 4.4, sold_at: "2026-05-14T10:00:00Z"},
            %{marketplace: "Blur", collection: "azuki", token_id: 3, price: 4.6, timestamp: "2026-05-15T10:00:00Z"}
          ],
          %{marketplace: "OpenSea"}
        )

      assert monitor.sale_count == 2
      assert monitor.total_volume == 8.6
      assert Enum.map(monitor.sales, & &1.token_id) == ["2", "1"]
      assert List.last(monitor.sales).timestamp == nil
    end
  end

  describe "rarity_scores/1" do
    test "ranks tokens by trait frequency rarity" do
      rarity =
        Marketplace.rarity_scores([
          %{token_id: 1, traits: %{background: "red", eyes: "laser"}},
          %{token_id: 2, traits: %{background: "red", eyes: "normal"}},
          %{token_id: 3, traits: %{background: "blue", eyes: "normal"}}
        ])

      assert rarity.supply == 3
      assert rarity.trait_frequencies["eyes:laser"] == 1

      [rarest | _] = rarity.tokens
      assert rarest.token_id == "1"
      assert rarest.rarity_rank == 1
      assert rarest.rarity_score == 4.5
    end
  end

  describe "market_trends/2" do
    test "buckets sales and computes deltas" do
      trends = Marketplace.market_trends(sample_sales(), %{bucket: :daily})

      assert trends.bucket == :daily
      assert Enum.map(trends.periods, & &1.period) == ["2026-05-11", "2026-05-12", "2026-05-13"]
      assert Enum.map(trends.periods, & &1.sale_count) == [1, 2, 1]
      assert trends.volume_delta == 1.4
      assert trends.sales_delta == 0.0
    end

    test "groups sales without timestamps into an unknown bucket" do
      trends =
        Marketplace.market_trends([
          %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 4.1},
          %{marketplace: "Blur", collection: "azuki", token_id: 2, price: "4.4", timestamp: "2026-05-12T09:00:00Z"}
        ])

      assert Enum.map(trends.periods, & &1.period) == ["2026-05-12", "unknown"]
      assert Enum.map(trends.periods, & &1.sale_count) == [1, 1]
    end
  end

  describe "cross_marketplace_report/1" do
    test "combines collection, price, sales, trend, rarity, and marketplace comparison" do
      report =
        Marketplace.cross_marketplace_report(%{
          collections: [
            %{marketplace: "OpenSea", slug: "azuki", floor_price: 4.2, volume: 1200, owners: 4300},
            %{marketplace: "Blur", slug: "azuki", floor_price: 4.0, volume: 950, owners: 4100}
          ],
          listings: [
            %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 4.2},
            %{marketplace: "Blur", collection: "azuki", token_id: 2, price: 4.0}
          ],
          sales: sample_sales(),
          tokens: [
            %{token_id: 1, traits: %{background: "red", eyes: "laser"}},
            %{token_id: 2, traits: %{background: "red", eyes: "normal"}}
          ]
        })

      assert report.collection.floor_price == 4.0
      assert report.prices.floor_price == 4.0
      assert report.sales.sale_count == 4
      assert report.trends.volume_delta == 1.4
      assert hd(report.rarity.tokens).rarity_rank == 1
      assert report.marketplace_comparison["blur"].floor_price == 4.0
      assert report.marketplace_comparison["opensea"].sales_volume == 9.6
    end

    test "returns stable empty report sections for empty inputs" do
      report = Marketplace.cross_marketplace_report(%{})

      assert report.collection.collection_count == 0
      assert report.prices.listing_count == 0
      assert report.sales.sale_count == 0
      assert report.trends.periods == []
      assert report.rarity.tokens == []
      assert report.marketplace_comparison == %{}
    end
  end

  defp sample_sales do
    [
      %{marketplace: "OpenSea", collection: "azuki", token_id: 1, price: 4.1, timestamp: "2026-05-11T10:00:00Z"},
      %{marketplace: "Blur", collection: "azuki", token_id: 2, price: "4.0", timestamp: "2026-05-12T09:00:00Z"},
      %{marketplace: "OpenSea", collection: "azuki", token_id: 3, price: 5.5, timestamp: "2026-05-13T11:00:00Z"},
      %{marketplace: "X2Y2", collection: "doodles", token_id: 9, price: 2.0, timestamp: "2026-05-12T12:00:00Z"}
    ]
  end
end

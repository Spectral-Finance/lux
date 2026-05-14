defmodule Lux.Integrations.NFT.MarketplaceAggregatorTest do
  use UnitCase, async: true

  alias Lux.Integrations.NFT.MarketplaceAggregator

  @attrs %{
    collection_slug: "azuki",
    contract_address: "0xed5af388653567af2f388e6224dc7c4b3241c544",
    chain: "ethereum",
    marketplaces: [
      %{
        marketplace: "opensea",
        stats: %{
          floor_price: "4.5",
          previous_floor_price: "4.0",
          volume_24h: "100.0",
          volume_7d: "700.0",
          listed_count: 10,
          owners: 5_000,
          sales_24h: 12
        },
        listings: [
          %{token_id: "1", price: "4.5", seller: "0xseller1"},
          %{token_id: "2", price: "5.0", seller: "0xseller2"}
        ],
        sales: [
          %{token_id: "8", price: "4.8", buyer: "0xbuyer", sold_at: "2026-05-13T10:00:00Z"}
        ],
        tokens: [
          %{
            token_id: "1",
            traits: [
              %{trait_type: "Background", value: "Red"},
              %{trait_type: "Eyes", value: "Gold"}
            ]
          },
          %{
            token_id: "2",
            traits: [
              %{trait_type: "Background", value: "Blue"},
              %{trait_type: "Eyes", value: "Blue"}
            ]
          }
        ]
      },
      %{
        marketplace: "blur",
        stats: %{
          floor_price: 4.1,
          previous_floor_price: 4.4,
          volume_24h: 140.0,
          volume_7d: 810.0,
          listed_count: 20,
          owners: 4_900,
          sales_24h: 20
        },
        listings: [
          %{token_id: "1", price: "4.1", seller: "0xblur"},
          %{token_id: "3", price: "4.2", seller: "0xblur2"}
        ],
        sales: [
          %{token_id: "3", price: 4.3, buyer: "0xbuyer2", sold_at: "2026-05-13T11:00:00Z"}
        ],
        tokens: [
          %{
            token_id: "3",
            traits: [
              %{trait_type: "Background", value: "Red"},
              %{trait_type: "Eyes", value: "Blue"}
            ]
          }
        ]
      }
    ]
  }

  test "aggregates collection stats, listings, prices, and sales across marketplaces" do
    report = MarketplaceAggregator.aggregate(@attrs)

    assert report.collection.slug == "azuki"
    assert :collection_data_aggregation in report.coverage
    assert report.collection_data.marketplaces == 2
    assert report.collection_data.volume_24h == 240.0
    assert report.price_tracking.lowest_floor.marketplace == "blur"
    assert report.price_tracking.lowest_floor.floor_price == 4.1
    assert report.price_tracking.spread_percent == 9.756098
    assert report.sales_monitoring.sales_count == 2
    assert report.sales_monitoring.total_volume == 9.1
    assert report.listing_management.active_count == 4
    assert report.cross_marketplace_comparison.listing_overlap == 1
  end

  test "calculates rarity scores and trait frequencies" do
    report = MarketplaceAggregator.aggregate(@attrs)

    assert report.trait_analysis.token_count == 3
    assert "Background" in report.trait_analysis.trait_types

    assert Enum.any?(
             report.trait_analysis.frequencies,
             &(&1.trait_type == "Eyes" and &1.value == "Gold")
           )

    assert length(report.rarity.tokens) == 3
    assert hd(report.rarity.tokens).rarity_rank == 1
    assert hd(report.rarity.tokens).rarity_score >= List.last(report.rarity.tokens).rarity_score
  end

  test "builds market trend and cross-marketplace comparison signals" do
    report = MarketplaceAggregator.aggregate(@attrs)

    opensea = Enum.find(report.market_trends.by_marketplace, &(&1.marketplace == "opensea"))
    blur = Enum.find(report.market_trends.by_marketplace, &(&1.marketplace == "blur"))

    assert opensea.trend == :up
    assert blur.trend == :down
    assert report.cross_marketplace_comparison.lowest_floor_marketplace.marketplace == "blur"
    assert report.cross_marketplace_comparison.highest_liquidity_marketplace.marketplace == "blur"
  end

  test "builds data collection request plans for OpenSea, Blur, and X2Y2" do
    plans =
      MarketplaceAggregator.request_plans(%{
        collection_slug: "azuki",
        contract_address: "0xed5af388653567af2f388e6224dc7c4b3241c544",
        marketplaces: ["opensea", "blur", "x2y2"]
      })

    assert length(plans) == 9
    assert Enum.any?(plans, &(&1.marketplace == "opensea" and &1.capability == :collection_stats))
    assert Enum.any?(plans, &(&1.marketplace == "blur" and &1.capability == :listings))
    assert Enum.any?(plans, &(&1.marketplace == "x2y2" and &1.capability == :sales))
    assert Enum.all?(plans, & &1.auth_required)
  end

  test "accepts string keyed marketplace payloads" do
    report =
      MarketplaceAggregator.aggregate(%{
        "collection_slug" => "doodles",
        "marketplaces" => [
          %{
            "marketplace" => "x2y2",
            "stats" => %{"floor_price" => "3.2", "listed_count" => "8"},
            "tokens" => [%{"token_id" => "9", "traits" => %{"Mood" => "Happy"}}]
          }
        ]
      })

    assert report.collection.slug == "doodles"
    assert report.price_tracking.lowest_floor.marketplace == "x2y2"
    assert report.price_tracking.lowest_floor.floor_price == 3.2
    assert report.rarity.tokens |> hd() |> Map.fetch!(:token_id) == "9"
  end
end

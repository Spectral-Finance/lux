defmodule Lux.Prisms.NftPrismsTest do
  use UnitCase, async: true

  alias Lux.Prisms.Nft.CollectionStatsPrism
  alias Lux.Prisms.Nft.FloorPricePrism
  alias Lux.Prisms.Nft.RarityScorePrism
  alias Lux.Prisms.Nft.SalesTrackerPrism
  alias Lux.Prisms.Nft.CrossMarketListingPrism

  describe "CollectionStatsPrism" do
    test "normalizes stats" do
      input = %{
        collection: "bored-ape-yacht-club",
        stats_data: %{"total" => %{"floor_price" => "11.5", "total_supply" => 10000}}
      }

      assert {:ok, result} = CollectionStatsPrism.run(input)
      assert result.floor_price_eth == 11.5
      assert result.total_supply == 10000
    end
  end

  describe "FloorPricePrism" do
    test "compares floor prices" do
      input = %{
        collection: "azuki",
        opensea_floor: 5.5,
        blur_floor: 5.3,
        looksrare_floor: 5.6
      }

      assert {:ok, result} = FloorPricePrism.run(input)
      assert result.lowest_floor_eth == 5.3
      assert result.best_marketplace == "blur"
    end
  end

  describe "RarityScorePrism" do
    test "evaluates token rarity" do
      input = %{
        token_id: 101,
        traits: [%{"trait_type" => "Hat", "value" => "Crown", "count" => 20}],
        total_supply: 10_000
      }

      assert {:ok, result} = RarityScorePrism.run(input)
      assert result.token_id == 101
      assert result.total_rarity_score == 500.0
      assert result.rarity_tier == "legendary"
    end
  end

  describe "SalesTrackerPrism" do
    test "tracks sales and filters wash volume" do
      input = %{
        sales: [
          %{"buyer" => "0x1", "seller" => "0x2", "price_eth" => 1.5}
        ]
      }

      assert {:ok, result} = SalesTrackerPrism.run(input)
      assert result.clean_sales_count == 1
      assert result.clean_volume_eth == 1.5
    end
  end

  describe "CrossMarketListingPrism" do
    test "compares listings" do
      input = %{
        listings: [%{"marketplace" => "opensea", "price_eth" => 2.0}]
      }

      assert {:ok, result} = CrossMarketListingPrism.run(input)
      assert result.best_marketplace == "opensea"
      assert result.lowest_total_cost_eth > 2.0
    end
  end
end

defmodule Lux.NFTMarketplaceTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.NFTMarketplace
  alias Lux.Prisms.NFTMarketplace.GetCollectionStats
  alias Lux.Prisms.NFTMarketplace.CalculateRarity
  alias Lux.Prisms.NFTMarketplace.CompareMarketplaces

  test "calculates rarity correctly based on traits frequency" do
    traits_data = %{
      "total_supply" => 100,
      "traits" => %{
        "Background" => %{"Red" => 80, "Gold" => 20},
        "Hat" => %{"Cap" => 90, "Crown" => 10}
      },
      "tokens" => [
        %{"token_id" => "1", "traits" => %{"Background" => "Red", "Hat" => "Cap"}}, # common
        %{"token_id" => "2", "traits" => %{"Background" => "Gold", "Hat" => "Crown"}} # rare
      ]
    }

    {:ok, result} = NFTMarketplace.calculate_rarity("test-collection", traits_data)

    assert result["collection"] == "test-collection"
    assert length(result["tokens"]) == 2

    [rare, common] = result["tokens"]
    assert rare["token_id"] == "2"
    assert rare["rarity_rank"] == 1
    # score: 100/20 + 100/10 = 5 + 10 = 15.0
    assert rare["rarity_score"] == 15.0

    assert common["token_id"] == "1"
    assert common["rarity_rank"] == 2
    # score: 100/80 + 100/90 = 1.25 + 1.11 = 2.36
    assert common["rarity_score"] == 2.36
  end

  test "compares marketplaces and selects best option" do
    {:ok, result} = NFTMarketplace.compare_marketplaces("boredapeyachtclub")
    
    assert result["collection"] == "boredapeyachtclub"
    # blur has -0.05 modifier, x2y2 has +0.03 modifier
    assert result["best_buy"] == "blur"
    assert result["best_sell"] == "x2y2"
  end

  test "prism handler retrieves stats successfully" do
    agent = %{name: "TestAgent"}
    {:ok, stats} = GetCollectionStats.handler(%{collection_slug: "pudgypenguins", marketplace: "opensea"}, agent)
    
    assert stats["collection"] == "pudgypenguins"
    assert stats["marketplace"] == "opensea"
    assert stats["floor_price"] == 9.5
  end
end

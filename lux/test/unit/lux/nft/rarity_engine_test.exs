defmodule Lux.Nft.RarityEngineTest do
  use UnitCase, async: true

  alias Lux.Nft.RarityEngine

  describe "calculate_trait_score/2" do
    test "calculates inverse frequency rarity score" do
      # 50 occurrences out of 10,000 = 10,000 / 50 = 200.0
      score = RarityEngine.calculate_trait_score(50, 10_000)
      assert score == 200.0
    end
  end

  describe "calculate_token_rarity/2" do
    test "aggregates trait scores and assigns tier" do
      traits = [
        %{"trait_type" => "Background", "value" => "Gold", "count" => 100},   # 10000 / 100 = 100
        %{"trait_type" => "Fur", "value" => "Trippy", "count" => 50},        # 10000 / 50 = 200
        %{"trait_type" => "Eyes", "value" => "Laser", "count" => 40}          # 10000 / 40 = 250
      ]

      result = RarityEngine.calculate_token_rarity(traits, 10_000)

      # 100 + 200 + 250 = 550 -> Legendary (>= 500)
      assert result.total_rarity_score == 550.0
      assert result.rarity_tier == :legendary
      assert length(result.trait_scores) == 3
    end

    test "handles common traits" do
      traits = [
        %{"trait_type" => "Background", "value" => "Blue", "count" => 2000} # 10000 / 2000 = 5
      ]

      result = RarityEngine.calculate_token_rarity(traits, 10_000)
      assert result.total_rarity_score == 5.0
      assert result.rarity_tier == :common
    end
  end
end

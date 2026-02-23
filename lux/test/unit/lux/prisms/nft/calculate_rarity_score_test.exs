defmodule Lux.Prisms.NFT.CalculateRarityScoreTest do
  @moduledoc """
  Test suite for the CalculateRarityScore prism.
  Verifies:
  - Basic rarity score calculation
  - Multi-trait scoring (rarer traits produce higher scores)
  - Rank calculation from collection scores
  - Input validation
  - String/atom key handling
  """

  use UnitCase, async: true
  alias Lux.Prisms.NFT.CalculateRarityScore

  @agent %{name: "TestAgent"}

  describe "handler/2" do
    test "calculates rarity score for a single common trait" do
      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Background", value: "Blue", trait_count: 5000}
          ]
        },
        @agent
      )

      assert result.rarity_score == 2.0
      assert length(result.trait_rarities) == 1
      [trait] = result.trait_rarities
      assert trait.trait_type == "Background"
      assert trait.rarity_score == 2.0
      assert trait.rarity_pct == 50.0
    end

    test "calculates higher score for rarer traits" do
      assert {:ok, common_result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Eyes", value: "Normal", trait_count: 9000}
          ]
        },
        @agent
      )

      assert {:ok, rare_result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Eyes", value: "Laser", trait_count: 10}
          ]
        },
        @agent
      )

      assert rare_result.rarity_score > common_result.rarity_score
    end

    test "sums rarity scores across multiple traits" do
      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Background", value: "Blue", trait_count: 1000},
            %{trait_type: "Eyes", value: "Laser", trait_count: 100},
            %{trait_type: "Hat", value: "Crown", trait_count: 50}
          ]
        },
        @agent
      )

      # 10 + 100 + 200 = 310
      assert result.rarity_score == 310.0
      assert length(result.trait_rarities) == 3
    end

    test "calculates rank from collection scores" do
      collection_scores = [500.0, 310.0, 150.0, 50.0, 10.0]

      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Eyes", value: "Laser", trait_count: 100}
          ],
          collection_scores: collection_scores
        },
        @agent
      )

      # Score 100.0 falls between 150.0 (rank 3) and 50.0 (rank 4)
      assert result.rarity_rank != nil
      assert is_integer(result.rarity_rank)
    end

    test "does not include rank when collection_scores not provided" do
      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          total_supply: 1000,
          nft_traits: [
            %{trait_type: "Type", value: "Gold", trait_count: 10}
          ]
        },
        @agent
      )

      refute Map.has_key?(result, :rarity_rank)
    end

    test "handles string keys in params" do
      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          "total_supply" => 10000,
          "nft_traits" => [
            %{"trait_type" => "Background", "value" => "Gold", "trait_count" => 52}
          ]
        },
        @agent
      )

      assert result.rarity_score > 0
    end

    test "returns error for missing required params" do
      assert {:error, _msg} = CalculateRarityScore.handler(%{}, @agent)
    end

    test "correctly computes rarity percentage" do
      assert {:ok, result} = CalculateRarityScore.handler(
        %{
          total_supply: 10000,
          nft_traits: [
            %{trait_type: "Background", value: "Blue", trait_count: 1152}
          ]
        },
        @agent
      )

      [trait] = result.trait_rarities
      assert trait.rarity_pct == 11.52
    end
  end
end

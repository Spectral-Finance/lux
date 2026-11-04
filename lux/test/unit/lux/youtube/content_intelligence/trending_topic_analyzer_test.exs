defmodule Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer

  describe "happy_path" do
    test "analyzes trending topics with valid data" do
      input = %{
        search_queries: ["cooking tutorial", "cake baking", "quick recipes"],
        trending_data: %{"cooking tutorial" => 85, "cake baking" => 45, "quick recipes" => 30},
        channel_niche: "cooking"
      }

      {:ok, result} = TrendingTopicAnalyzer.analyze(input)

      assert is_list(result.search_momentum)
      assert length(result.search_momentum) == 3
      assert result.saturation_index >= 0
      assert is_list(result.content_classification)
      assert is_list(result.evergreen_topics)
      assert is_list(result.viral_topics)
      assert is_list(result.recommended_opportunities)
    end

    test "calculates momentum score" do
      score = TrendingTopicAnalyzer.momentum_score("cooking", %{"cooking" => 85, "baking" => 45})
      assert score == 85
    end

    test "returns zero for unknown topic momentum" do
      score = TrendingTopicAnalyzer.momentum_score("unknown", %{"cooking" => 85})
      assert score == 0
    end

    test "calculates saturation index" do
      data = %{"a" => 50, "b" => 70, "c" => 30}
      index = TrendingTopicAnalyzer.saturation_index(data)
      assert index == 50  # average of 50, 70, 30
    end

    test "classifies viral content" do
      classification = TrendingTopicAnalyzer.classify("trending", %{"trending" => 90})
      assert classification == "viral"
    end

    test "classifies evergreen content" do
      classification = TrendingTopicAnalyzer.classify("stable", %{"stable" => 30})
      assert classification == "evergreen"
    end
  end

  describe "boundary" do
    test "handles empty search queries" do
      input = %{
        search_queries: [],
        trending_data: %{"a" => 50},
        channel_niche: "cooking"
      }

      {:ok, result} = TrendingTopicAnalyzer.analyze(input)
      assert result.search_momentum == []
      assert result.content_classification == []
    end

    test "handles empty trending data" do
      input = %{
        search_queries: ["test"],
        trending_data: %{},
        channel_niche: "cooking"
      }

      {:ok, result} = TrendingTopicAnalyzer.analyze(input)
      assert result.saturation_index == 0
    end

    test "handles high saturation (boundary)" do
      input = %{
        search_queries: ["test"],
        trending_data: %{"test" => 100},
        channel_niche: "cooking"
      }

      {:ok, result} = TrendingTopicAnalyzer.analyze(input)
      assert result.saturation_index == 100
    end
  end

  describe "null_input" do
    test "returns error for nil input" do
      assert {:error, :invalid_input} = TrendingTopicAnalyzer.analyze(nil)
    end

    test "returns error for missing required fields" do
      input = %{search_queries: []}
      assert {:error, {:missing_fields, _}} = TrendingTopicAnalyzer.analyze(input)
    end
  end

  describe "empty_input" do
    test "rejects empty map input" do
      assert {:error, {:missing_fields, _}} = TrendingTopicAnalyzer.analyze(%{})
    end

    test "rejects non-list search_queries" do
      input = %{search_queries: "not_a_list", trending_data: %{}, channel_niche: "cooking"}
      assert {:error, {:invalid_value, :search_queries}} = TrendingTopicAnalyzer.analyze(input)
    end
  end

  describe "negative" do
    test "rejects non-map trending_data" do
      input = %{search_queries: [], trending_data: "not_a_map", channel_niche: "cooking"}
      assert {:error, {:invalid_value, :trending_data}} = TrendingTopicAnalyzer.analyze(input)
    end

    test "rejects non-binary channel_niche" do
      input = %{search_queries: [], trending_data: %{}, channel_niche: 123}
      assert {:error, {:invalid_value, :channel_niche}} = TrendingTopicAnalyzer.analyze(input)
    end
  end
end
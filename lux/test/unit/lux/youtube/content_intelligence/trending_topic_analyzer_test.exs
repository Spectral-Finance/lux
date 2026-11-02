defmodule Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentIntelligence.TrendingTopicAnalyzer

  describe "analyze_niche_trends/1" do
    test "fetches trending dataset with momentum and opportunity scores" do
      trends = TrendingTopicAnalyzer.analyze_niche_trends("ai")

      assert length(trends) > 0
      first = List.first(trends)
      assert is_binary(first.topic)
      assert first.niche == "ai"
      assert first.search_momentum_percentage > 0
      assert first.opportunity_score > 0
      assert first.recommendation in [:produce_immediately, :schedule_in_queue, :monitor_only]
    end
  end

  describe "evaluate_custom_topic/3" do
    test "evaluates custom parameters correctly" do
      result = TrendingTopicAnalyzer.evaluate_custom_topic(
        "Fine-tuning DeepSeek V3",
        "ai",
        %{momentum: 220.0, saturation: 0.25}
      )

      assert result.topic == "Fine-tuning DeepSeek V3"
      assert result.opportunity_score >= 80.0
      assert result.recommendation == :produce_immediately
    end
  end
end

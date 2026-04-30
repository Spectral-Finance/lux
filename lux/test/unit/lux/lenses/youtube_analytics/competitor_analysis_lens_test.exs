defmodule Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens

  describe "focus/1" do
    test "has correct lens metadata" do
      assert Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens.__meta__(:name) == "YouTube Competitor Analysis"
    end

    test "schema has required fields" do
      schema = Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens.__schema__()
      assert "target_channel_id" in schema[:required]
      assert "competitor_channel_ids" in schema[:required]
    end

    test "output schema defines comparison fields" do
      output = Lux.Lenses.YoutubeAnalytics.CompetitorAnalysisLens.__output_schema__()
      assert output[:properties][:comparison] != nil
      assert output[:properties][:competitors] != nil
      assert output[:properties][:target] != nil
    end
  end
end

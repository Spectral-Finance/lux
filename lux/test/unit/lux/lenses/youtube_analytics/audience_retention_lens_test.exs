defmodule Lux.Lenses.YoutubeAnalytics.AudienceRetentionLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens

  describe "focus/1" do
    test "has correct lens metadata" do
      assert Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens.__meta__(:name) == "YouTube Audience Retention"
    end

    test "schema has required fields" do
      schema = Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens.__schema__()
      assert "video_id" in schema[:required]
      assert "start_date" in schema[:required]
      assert "end_date" in schema[:required]
    end

    test "output schema defines retention fields" do
      output = Lux.Lenses.YoutubeAnalytics.AudienceRetentionLens.__output_schema__()
      assert output[:properties][:average_view_percentage] != nil
      assert output[:properties][:daily_retention] != nil
      assert output[:properties][:insights] != nil
    end
  end
end

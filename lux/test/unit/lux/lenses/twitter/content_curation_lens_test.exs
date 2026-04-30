defmodule Lux.Lenses.Twitter.ContentCurationLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.Twitter.ContentCurationLens

  describe "focus/1" do
    test "has correct lens metadata" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      assert lens.name == "Twitter Content Curation"
      assert lens.description != ""
      assert lens.url != ""
    end

    test "schema has expected properties" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      properties = lens.schema[:properties]
      assert Map.has_key?(properties, "keywords")
      assert Map.has_key?(properties, "hashtags")
      assert Map.has_key?(properties, "min_engagement")
      assert Map.has_key?(properties, "max_results")
      assert Map.has_key?(properties, "language")
      assert Map.has_key?(properties, "content_type")
    end

    test "default min_engagement is 0" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      min_engagement_prop = lens.schema[:properties]["min_engagement"]
      assert min_engagement_prop[:default] == 0
    end

    test "default max_results is 20" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      max_results_prop = lens.schema[:properties]["max_results"]
      assert max_results_prop[:default] == 20
    end

    test "default language is en" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      language_prop = lens.schema[:properties]["language"]
      assert language_prop[:default] == "en"
    end

    test "content_type has enum constraint" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      content_type_prop = lens.schema[:properties]["content_type"]
      assert content_type_prop[:enum] != nil
      assert "any" in content_type_prop[:enum]
      assert "original" in content_type_prop[:enum]
      assert "media" in content_type_prop[:enum]
    end

    test "output schema has expected fields" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      output = lens.output_schema
      assert Map.has_key?(output[:properties], "trending")
      assert Map.has_key?(output[:properties], "curated")
      assert Map.has_key?(output[:properties], "topics")
      assert Map.has_key?(output[:properties], "search_metadata")
    end

    test "search_metadata has expected sub-properties" do
      lens = Lux.Lenses.Twitter.ContentCurationLens.view()
      search_meta = lens.output_schema[:properties]["search_metadata"]
      assert Map.has_key?(search_meta[:properties], "total_results")
      assert Map.has_key?(search_meta[:properties], "query")
      assert Map.has_key?(search_meta[:properties], "search_time")
    end
  end
end

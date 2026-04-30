defmodule Lux.Lenses.Twitter.TwitterTimelineLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.Twitter.TwitterTimelineLens

  describe "focus/1" do
    test "has correct lens metadata" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      assert lens.name == "Twitter Timeline"
      assert lens.description != ""
      assert lens.url != ""
    end

    test "schema has required fields" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      assert "user_id" in lens.schema[:required]
    end

    test "schema has expected properties" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      properties = lens.schema[:properties]
      assert Map.has_key?(properties, "user_id")
      assert Map.has_key?(properties, "max_results")
      assert Map.has_key?(properties, "tweet_fields")
      assert Map.has_key?(properties, "exclude")
    end

    test "default max_results is 10" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      max_results_prop = lens.schema[:properties]["max_results"]
      assert max_results_prop[:default] == 10
    end

    test "default exclude is retweets" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      exclude_prop = lens.schema[:properties]["exclude"]
      assert exclude_prop[:default] == "retweets"
    end

    test "output schema has expected fields" do
      lens = Lux.Lenses.Twitter.TwitterTimelineLens.view()
      output = lens.output_schema
      assert Map.has_key?(output[:properties], "user_id")
      assert Map.has_key?(output[:properties], "tweets")
      assert Map.has_key?(output[:properties], "total_count")
    end
  end
end

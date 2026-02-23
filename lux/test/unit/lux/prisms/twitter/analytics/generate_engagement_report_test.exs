defmodule Lux.Prisms.Twitter.Analytics.GenerateEngagementReportTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.Analytics.GenerateEngagementReport

  @agent_ctx %{name: "TestAgent"}

  @sample_tweets [
    %{tweet_id: "1", text: "First tweet", metrics: %{like_count: 100, retweet_count: 50, reply_count: 20, quote_count: 10, impression_count: 5000, bookmark_count: 15}},
    %{tweet_id: "2", text: "Second tweet", metrics: %{like_count: 200, retweet_count: 80, reply_count: 40, quote_count: 20, impression_count: 8000, bookmark_count: 25}}
  ]

  describe "handler/2" do
    test "generates a report with totals and averages" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: @sample_tweets, username: "testuser"}, @agent_ctx)
      assert report.tweet_count == 2
      assert report.username == "testuser"
      assert report.totals.likes == 300
      assert report.totals.retweets == 130
      assert report.totals.impressions == 13_000
      assert report.averages.likes_per_tweet == 150.0
    end

    test "identifies top tweets" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: @sample_tweets}, @agent_ctx)
      assert length(report.top_tweets) <= 3
      assert length(report.top_tweets) == 2
      # Second tweet should rank higher (more engagement)
      first_top = List.first(report.top_tweets)
      assert first_top.tweet_id == "2"
    end

    test "generates insights for the data" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: @sample_tweets}, @agent_ctx)
      assert is_list(report.insights)
      assert length(report.insights) > 0
    end

    test "handles empty tweet list" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: []}, @agent_ctx)
      assert report.tweet_count == 0
      assert report.totals.likes == 0
      assert report.averages.likes_per_tweet == 0.0
    end

    test "uses custom period label" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: @sample_tweets, period: "last_7_days"}, @agent_ctx)
      assert report.report_period == "last_7_days"
    end

    test "accepts string keys" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{"tweets" => @sample_tweets, "username" => "user"}, @agent_ctx)
      assert report.username == "user"
    end

    test "calculates engagement rate from impressions" do
      assert {:ok, report} = GenerateEngagementReport.handler(%{tweets: @sample_tweets}, @agent_ctx)
      assert report.averages.engagement_rate > 0
    end
  end
end

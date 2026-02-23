defmodule Lux.Prisms.Twitter.Automation.ApplyEngagementRulesTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.ApplyEngagementRules

  @agent %{name: "EngagementBot"}
  @tweet %{
    id: "tweet_abc_123",
    text: "Love using #Elixir for building scalable systems!",
    author_id: "user_456",
    metrics: %{like_count: 75, retweet_count: 15, reply_count: 8}
  }

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "matches keyword rule and executes like action" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets/tweet_abc_123/likes"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"liked" => true}}))
      end)

      assert {:ok, result} = ApplyEngagementRules.handler(%{
        tweet: @tweet,
        rules: [%{condition: %{keywords: ["elixir", "phoenix"]}, action: "like"}]
      }, @agent)

      assert result.tweet_id == "tweet_abc_123"
      assert length(result.matched_rules) == 1
      assert "like" in result.actions_taken
    end

    test "dry run does not execute actions" do
      assert {:ok, result} = ApplyEngagementRules.handler(%{
        tweet: @tweet,
        rules: [%{condition: %{keywords: ["elixir"]}, action: "like"}],
        dry_run: true
      }, @agent)

      assert result.dry_run == true
      assert result.actions_taken == []
      assert result.would_execute == ["like"]
    end

    test "matches min_likes condition" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.request_path == "/2/tweets/tweet_abc_123/retweets"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"retweeted" => true}}))
      end)

      assert {:ok, result} = ApplyEngagementRules.handler(%{
        tweet: @tweet,
        rules: [%{condition: %{min_likes: 50}, action: "retweet"}]
      }, @agent)

      assert "retweet" in result.actions_taken
    end

    test "no rules match for low-engagement tweet" do
      low_tweet = %{@tweet | metrics: %{like_count: 1, retweet_count: 0, reply_count: 0}}

      assert {:ok, result} = ApplyEngagementRules.handler(%{
        tweet: low_tweet,
        rules: [%{condition: %{min_likes: 100}, action: "like"}]
      }, @agent)

      assert result.matched_rules == []
      assert result.actions_taken == []
    end

    test "multiple rules can match simultaneously" do
      Req.Test.expect(TwitterClientMock, 2, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"liked" => true}}))
      end)

      assert {:ok, result} = ApplyEngagementRules.handler(%{
        tweet: @tweet,
        rules: [
          %{condition: %{keywords: ["elixir"]}, action: "like"},
          %{condition: %{min_likes: 50}, action: "like"}
        ]
      }, @agent)

      assert length(result.matched_rules) == 2
    end

    test "returns error for missing required parameters" do
      assert {:error, _} = ApplyEngagementRules.handler(%{tweet: @tweet}, @agent)
    end
  end
end

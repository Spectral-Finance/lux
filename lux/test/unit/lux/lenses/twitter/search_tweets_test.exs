defmodule Lux.Lenses.Twitter.SearchTweetsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.SearchTweets

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "focus/1" do
    test "searches tweets and returns results" do
      Req.Test.stub(SearchTweets, fn conn ->
        Req.Test.json(conn, %{
          "data" => [
            %{"id" => "1", "text" => "hello", "author_id" => "a1", "created_at" => "2026-01-01T00:00:00Z", "lang" => "en",
              "public_metrics" => %{"like_count" => 5, "retweet_count" => 2, "reply_count" => 1}},
            %{"id" => "2", "text" => "world", "author_id" => "a2", "created_at" => "2026-01-01T01:00:00Z", "lang" => "en",
              "public_metrics" => %{"like_count" => 10, "retweet_count" => 3, "reply_count" => 0}}
          ],
          "meta" => %{"result_count" => 2, "newest_id" => "2", "oldest_id" => "1", "next_token" => "abc"}
        })
      end)

      assert {:ok, result} = SearchTweets.focus(%{query: "hello"})
      assert result.count == 2
      assert result.next_token == "abc"
      assert length(result.tweets) == 2
      assert hd(result.tweets).id == "1"
      assert hd(result.tweets).metrics.likes == 5
    end

    test "handles empty results" do
      Req.Test.stub(SearchTweets, fn conn ->
        Req.Test.json(conn, %{"meta" => %{"result_count" => 0}})
      end)

      assert {:ok, %{tweets: [], count: 0}} = SearchTweets.focus(%{query: "nonexistent"})
    end

    test "handles errors" do
      Req.Test.stub(SearchTweets, fn conn ->
        Req.Test.json(conn, %{"errors" => [%{"detail" => "Invalid query"}]})
      end)

      assert {:error, "Invalid query"} = SearchTweets.focus(%{query: ""})
    end
  end
end

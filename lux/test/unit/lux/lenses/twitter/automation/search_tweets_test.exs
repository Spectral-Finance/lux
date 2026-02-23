defmodule Lux.Lenses.Twitter.Automation.SearchTweetsTest do
  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Automation.SearchTweets

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully searches tweets with query" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/search/recent"
        params = URI.decode_query(conn.query_string)
        assert params["query"] == "#elixir"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "1", "text" => "Love #elixir!", "author_id" => "100",
              "created_at" => "2024-01-01T10:00:00Z",
              "public_metrics" => %{"like_count" => 42, "retweet_count" => 10, "reply_count" => 5}},
            %{"id" => "2", "text" => "Elixir is great for concurrency", "author_id" => "200",
              "created_at" => "2024-01-01T09:00:00Z",
              "public_metrics" => %{"like_count" => 25, "retweet_count" => 3, "reply_count" => 2}}
          ],
          "meta" => %{"result_count" => 2, "newest_id" => "1", "oldest_id" => "2"}
        }))
      end)

      assert {:ok, result} = SearchTweets.focus(%{"query" => "#elixir"}, %{})
      assert length(result.tweets) == 2
      assert result.result_count == 2
      assert result.newest_id == "1"
      assert hd(result.tweets).id == "1"
      assert hd(result.tweets).text == "Love #elixir!"
    end

    test "returns empty result when no tweets found" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "meta" => %{"result_count" => 0}
        }))
      end)

      assert {:ok, result} = SearchTweets.focus(%{"query" => "#nonexistent12345"}, %{})
      assert result.tweets == []
      assert result.result_count == 0
    end

    test "passes max_results parameter" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        params = URI.decode_query(conn.query_string)
        assert params["max_results"] == "50"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [],
          "meta" => %{"result_count" => 0}
        }))
      end)

      SearchTweets.focus(%{"query" => "#test", "max_results" => 50}, %{})
    end

    test "handles API rate limit error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, :rate_limited} = SearchTweets.focus(%{"query" => "#test"}, %{})
    end

    test "handles unauthorized error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn |> Plug.Conn.send_resp(401, "")
      end)

      assert {:error, :unauthorized} = SearchTweets.focus(%{"query" => "#test"}, %{})
    end

    test "includes next_token in result for pagination" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [%{"id" => "1", "text" => "Tweet", "author_id" => "100",
            "public_metrics" => %{"like_count" => 5, "retweet_count" => 1, "reply_count" => 0}}],
          "meta" => %{"result_count" => 1, "next_token" => "page2token", "newest_id" => "1", "oldest_id" => "1"}
        }))
      end)

      assert {:ok, result} = SearchTweets.focus(%{"query" => "#elixir"}, %{})
      assert result.next_token == "page2token"
    end
  end
end

defmodule Lux.Prisms.Twitter.Automation.CurateContentTest do
  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Automation.CurateContent

  @agent %{name: "ContentBot"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully curates content with quality filters" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "1", "text" => "Elixir is amazing!", "author_id" => "a1",
              "public_metrics" => %{"like_count" => 100, "retweet_count" => 25, "reply_count" => 10}},
            %{"id" => "2", "text" => "Phoenix LiveView rocks", "author_id" => "a2",
              "public_metrics" => %{"like_count" => 3, "retweet_count" => 0, "reply_count" => 1}},
            %{"id" => "3", "text" => "Building with Elixir", "author_id" => "a3",
              "public_metrics" => %{"like_count" => 50, "retweet_count" => 10, "reply_count" => 5}}
          ],
          "meta" => %{"result_count" => 3}
        }))
      end)

      assert {:ok, result} = CurateContent.handler(%{
        query: "#elixir",
        min_likes: 10,
        min_retweets: 5
      }, @agent)

      assert result.total_found == 3
      assert result.passed_filters == 2
      assert length(result.curated_tweets) == 2
    end

    test "filters out tweets with excluded keywords" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "1", "text" => "Good Elixir content", "author_id" => "a1",
              "public_metrics" => %{"like_count" => 50, "retweet_count" => 10, "reply_count" => 5}},
            %{"id" => "2", "text" => "Spam! Buy now! Elixir crypto", "author_id" => "a2",
              "public_metrics" => %{"like_count" => 50, "retweet_count" => 10, "reply_count" => 5}}
          ],
          "meta" => %{"result_count" => 2}
        }))
      end)

      assert {:ok, result} = CurateContent.handler(%{
        query: "#elixir",
        exclude_keywords: ["spam", "buy now"]
      }, @agent)

      assert result.passed_filters == 1
      assert hd(result.curated_tweets).id == "1"
    end

    test "returns empty result when no tweets match query" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "meta" => %{"result_count" => 0}
        }))
      end)

      assert {:ok, result} = CurateContent.handler(%{query: "#noresults999"}, @agent)
      assert result.curated_tweets == []
      assert result.total_found == 0
    end

    test "returns error for missing query" do
      assert {:error, _} = CurateContent.handler(%{min_likes: 10}, @agent)
    end
  end
end

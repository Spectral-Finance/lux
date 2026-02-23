defmodule Lux.Lenses.Twitter.Tweets.SearchTweetsTest do
  @moduledoc """
  Test suite for the SearchTweets lens.
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.SearchTweets

  describe "after_focus/1" do
    test "successfully transforms search results" do
      response = %{
        "data" => [
          %{"id" => "2001", "text" => "Elixir is awesome!"},
          %{"id" => "2002", "text" => "I love Elixir programming"}
        ],
        "meta" => %{
          "result_count" => 2,
          "newest_id" => "2002",
          "oldest_id" => "2001"
        }
      }

      assert {:ok, result} = SearchTweets.after_focus(response)
      assert length(result.data) == 2
      assert hd(result.data).id == "2001"
      assert hd(result.data).text == "Elixir is awesome!"
      assert result.meta.result_count == 2
      assert result.meta.newest_id == "2002"
    end

    test "handles empty results" do
      response = %{
        "meta" => %{"result_count" => 0}
      }

      assert {:ok, result} = SearchTweets.after_focus(response)
      assert result.data == []
      assert result.meta.result_count == 0
    end

    test "includes optional tweet fields" do
      response = %{
        "data" => [
          %{
            "id" => "2001",
            "text" => "Elixir tweet",
            "author_id" => "555",
            "created_at" => "2024-01-15T12:00:00Z",
            "lang" => "en",
            "possibly_sensitive" => false,
            "public_metrics" => %{
              "retweet_count" => 10,
              "reply_count" => 5,
              "like_count" => 100,
              "quote_count" => 2
            }
          }
        ],
        "meta" => %{"result_count" => 1, "newest_id" => "2001", "oldest_id" => "2001"}
      }

      assert {:ok, result} = SearchTweets.after_focus(response)
      tweet = hd(result.data)
      assert tweet.author_id == "555"
      assert tweet.lang == "en"
      assert tweet.possibly_sensitive == false
      assert tweet.public_metrics.like_count == 100
    end

    test "handles pagination tokens" do
      response = %{
        "data" => [%{"id" => "3001", "text" => "Page 2 tweet"}],
        "meta" => %{
          "result_count" => 1,
          "next_token" => "next_page_xyz",
          "previous_token" => "prev_page_abc",
          "newest_id" => "3001",
          "oldest_id" => "3001"
        }
      }

      assert {:ok, result} = SearchTweets.after_focus(response)
      assert result.meta.next_token == "next_page_xyz"
      assert result.meta.previous_token == "prev_page_abc"
    end

    test "handles invalid request error" do
      response = %{
        "title" => "Invalid Request",
        "detail" => "Your query syntax is invalid"
      }

      assert {:error, %{title: "Invalid Request", detail: "Your query syntax is invalid"}} =
        SearchTweets.after_focus(response)
    end

    test "handles errors array format" do
      response = %{
        "errors" => [%{
          "title" => "Forbidden",
          "detail" => "Access to search is not permitted"
        }]
      }

      assert {:error, %{title: "Forbidden"}} = SearchTweets.after_focus(response)
    end

    test "handles unexpected response" do
      assert {:error, %{title: "Unexpected response"}} =
        SearchTweets.after_focus(%{"weird" => "data"})
    end
  end

  describe "focus/2 integration" do
    setup do
      Req.Test.verify_on_exit!()
      :ok
    end

    test "successfully searches recent tweets" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/search/recent"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => [
            %{"id" => "4001", "text" => "Elixir is great!"}
          ],
          "meta" => %{
            "result_count" => 1,
            "newest_id" => "4001",
            "oldest_id" => "4001"
          }
        }))
      end)

      assert {:ok, result} = SearchTweets.focus(%{"query" => "Elixir"})
      assert length(result.data) == 1
      assert hd(result.data).id == "4001"
    end

    test "handles no results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "meta" => %{"result_count" => 0}
        }))
      end)

      assert {:ok, result} = SearchTweets.focus(%{"query" => "xyzabc123notfound"})
      assert result.data == []
    end
  end
end

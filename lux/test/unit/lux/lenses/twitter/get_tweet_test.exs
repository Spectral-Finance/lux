defmodule Lux.Lenses.Twitter.GetTweetTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.GetTweet
  alias Lux.Integrations.Twitter.Client, as: TwitterClient

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "focus/1" do
    test "fetches tweet with includes" do
      Req.Test.stub(TwitterClient, fn conn ->
        assert conn.request_path == "/2/tweets/123"

        Req.Test.json(conn, %{
          "data" => %{
            "id" => "123",
            "text" => "Hello world",
            "author_id" => "456",
            "created_at" => "2026-01-01T00:00:00Z",
            "conversation_id" => "123",
            "lang" => "en",
            "public_metrics" => %{
              "like_count" => 42, "retweet_count" => 10, "reply_count" => 5,
              "quote_count" => 2, "impression_count" => 1000
            }
          },
          "includes" => %{
            "users" => [%{"id" => "456", "name" => "Test", "username" => "test"}]
          }
        })
      end)

      assert {:ok, tweet} = GetTweet.focus(%{tweet_id: "123"})
      assert tweet.id == "123"
      assert tweet.text == "Hello world"
      assert tweet.author.username == "test"
      assert tweet.metrics.likes == 42
      assert tweet.metrics.impressions == 1000
    end

    test "fetches tweet without includes" do
      Req.Test.stub(TwitterClient, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{"id" => "789", "text" => "No includes", "author_id" => "111"}
        })
      end)

      assert {:ok, tweet} = GetTweet.focus(%{tweet_id: "789"})
      assert tweet.id == "789"
      assert tweet.author == nil
    end

    test "handles errors" do
      Req.Test.stub(TwitterClient, fn conn ->
        conn |> Plug.Conn.send_resp(401, Jason.encode!(%{"errors" => [%{"detail" => "Not authorized"}]}))
      end)

      assert {:error, :unauthorized} = GetTweet.focus(%{tweet_id: "000"})
    end
  end
end

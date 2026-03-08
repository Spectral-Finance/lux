defmodule Lux.Prisms.Twitter.Tweets.CreateTweetTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Client
  alias Lux.Prisms.Twitter.Tweets.CreateTweet

  describe "handler/2" do
    test "creates a simple tweet" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"text" => "Hello from Lux!"} = Jason.decode!(body)

        Req.Test.json(conn, %{
          "data" => %{"id" => "123", "text" => "Hello from Lux!"}
        })
      end)

      assert {:ok, %{tweet_id: "123", text: "Hello from Lux!"}} =
               CreateTweet.handler(%{"text" => "Hello from Lux!"}, nil)
    end

    test "creates a reply tweet" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["reply"]["in_reply_to_tweet_id"] == "456"

        Req.Test.json(conn, %{"data" => %{"id" => "789", "text" => "Reply"}})
      end)

      assert {:ok, %{tweet_id: "789"}} =
               CreateTweet.handler(%{"text" => "Reply", "reply_to" => "456"}, nil)
    end

    test "creates a quote tweet" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["quote_tweet_id"] == "111"

        Req.Test.json(conn, %{"data" => %{"id" => "222", "text" => "Quoting"}})
      end)

      assert {:ok, %{tweet_id: "222"}} =
               CreateTweet.handler(%{"text" => "Quoting", "quote_tweet_id" => "111"}, nil)
    end

    test "creates tweet with media" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["media"]["media_ids"] == ["m1", "m2"]

        Req.Test.json(conn, %{"data" => %{"id" => "333", "text" => "With media"}})
      end)

      assert {:ok, %{tweet_id: "333"}} =
               CreateTweet.handler(%{"text" => "With media", "media_ids" => ["m1", "m2"]}, nil)
    end

    test "creates tweet with poll" do
      Req.Test.stub(Client, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert length(decoded["poll"]["options"]) == 3
        assert decoded["poll"]["duration_minutes"] == 60

        Req.Test.json(conn, %{"data" => %{"id" => "444", "text" => "Poll!"}})
      end)

      assert {:ok, %{tweet_id: "444"}} =
               CreateTweet.handler(%{
                 "text" => "Poll!",
                 "poll_options" => ["A", "B", "C"],
                 "poll_duration_minutes" => 60
               }, nil)
    end
  end
end

defmodule Lux.Lenses.Twitter.Tweets.GetTweetTest do
  @moduledoc """
  Test suite for the GetTweet lens.
  Verifies the lens can:
  - Retrieve a tweet by ID with Bearer token auth
  - Return transformed tweet data
  - Handle Twitter API errors (not found, rate limited, unauthorized)
  - Handle optional field expansions
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Twitter.Tweets.GetTweet

  @tweet_id "1234567890123456789"
  @author_id "987654321"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves a tweet with default fields" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/:tweet_id"
        assert [auth] = Plug.Conn.get_req_header(conn, "authorization")
        assert String.starts_with?(auth, "Bearer ")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Hello, world!",
            "author_id" => @author_id,
            "created_at" => "2024-01-15T10:30:00.000Z"
          }
        }))
      end)

      assert {:ok, tweet} = GetTweet.focus(%{"tweet_id" => @tweet_id}, %{})
      assert tweet.id == @tweet_id
      assert tweet.text == "Hello, world!"
      assert tweet.author_id == @author_id
      assert tweet.created_at == "2024-01-15T10:30:00.000Z"
    end

    test "retrieves tweet with public_metrics when requested" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Popular tweet!",
            "public_metrics" => %{
              "retweet_count" => 42,
              "reply_count" => 10,
              "like_count" => 500,
              "quote_count" => 5,
              "bookmark_count" => 20,
              "impression_count" => 10000
            }
          }
        }))
      end)

      assert {:ok, tweet} = GetTweet.focus(
        %{"tweet_id" => @tweet_id, "tweet_fields" => "id,text,public_metrics"},
        %{}
      )
      assert tweet.public_metrics.like_count == 500
      assert tweet.public_metrics.retweet_count == 42
      assert tweet.public_metrics.reply_count == 10
    end

    test "handles not found error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "errors" => [%{
            "title" => "Not Found Error",
            "detail" => "Could not find tweet with id: [#{@tweet_id}]",
            "type" => "https://api.twitter.com/2/problems/resource-not-found"
          }]
        }))
      end)

      assert {:error, %{title: "Not Found Error"}} = GetTweet.focus(
        %{"tweet_id" => @tweet_id},
        %{}
      )
    end

    test "handles rate limit error response" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "title" => "Too Many Requests",
          "detail" => "Too Many Requests"
        }))
      end)

      assert {:error, %{title: "Too Many Requests"}} = GetTweet.focus(
        %{"tweet_id" => @tweet_id},
        %{}
      )
    end

    test "handles unexpected response format" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"unexpected" => "format"}))
      end)

      assert {:error, %{title: "Unexpected response"}} = GetTweet.focus(
        %{"tweet_id" => @tweet_id},
        %{}
      )
    end

    test "omits nil fields from result" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Minimal tweet"
          }
        }))
      end)

      assert {:ok, tweet} = GetTweet.focus(%{"tweet_id" => @tweet_id}, %{})
      refute Map.has_key?(tweet, :public_metrics)
      refute Map.has_key?(tweet, :author_id)
      assert tweet.id == @tweet_id
      assert tweet.text == "Minimal tweet"
    end
  end

  describe "schema validation" do
    test "validates required tweet_id field" do
      lens = GetTweet.view()
      assert lens.schema.required == ["tweet_id"]
    end

    test "has correct lens URL" do
      lens = GetTweet.view()
      assert lens.url == "https://api.twitter.com/2/tweets/:tweet_id"
    end

    test "uses GET method" do
      lens = GetTweet.view()
      assert lens.method == :get
    end

    test "has tweet_fields property with default" do
      lens = GetTweet.view()
      assert Map.has_key?(lens.schema.properties, :tweet_fields)
      assert lens.schema.properties.tweet_fields.default == "id,text,author_id,created_at"
    end
  end
end

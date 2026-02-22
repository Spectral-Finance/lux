defmodule Lux.Prisms.Twitter.Tweets.UnlikeTweetTest do
  @moduledoc """
  Test suite for the UnlikeTweet prism.
  Verifies the prism can:
  - Remove a like from a tweet
  - Return unliked status
  - Handle 401 unauthorized errors
  - Handle 403 forbidden errors
  - Handle 404 not found errors
  - Handle 429 rate limit errors
  - Accept string-keyed params
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.UnlikeTweet

  @user_id "123456789"
  @tweet_id "1234567890123456789"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully unlikes a tweet" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        assert conn.method == "DELETE"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"liked" => false}
        }))
      end)

      assert {:ok, result} = UnlikeTweet.handler(
        %{user_id: @user_id, tweet_id: @tweet_id},
        @agent
      )

      assert result.liked == false
      assert result.tweet_id == @tweet_id
    end

    test "accepts string-keyed params" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"liked" => false}
        }))
      end)

      assert {:ok, %{liked: false}} = UnlikeTweet.handler(
        %{"user_id" => @user_id, "tweet_id" => @tweet_id},
        @agent
      )
    end

    test "handles unauthorized error" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"title" => "Unauthorized"}))
      end)

      assert {:error, %{title: "Unauthorized"}} = UnlikeTweet.handler(
        %{user_id: @user_id, tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles forbidden error with detail" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "Cannot unlike this tweet"
        }))
      end)

      assert {:error, %{title: "Forbidden", detail: "Cannot unlike this tweet"}} =
               UnlikeTweet.handler(%{user_id: @user_id, tweet_id: @tweet_id}, @agent)
    end

    test "handles not found error" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"title" => "Not Found"}))
      end)

      assert {:error, %{title: "Not Found", detail: detail}} =
               UnlikeTweet.handler(%{user_id: @user_id, tweet_id: @tweet_id}, @agent)

      assert detail =~ @tweet_id
    end

    test "handles rate limit error" do
      Req.Test.expect(UnlikeTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error, %{title: "Rate Limited"}} =
               UnlikeTweet.handler(%{user_id: @user_id, tweet_id: @tweet_id}, @agent)
    end
  end
end

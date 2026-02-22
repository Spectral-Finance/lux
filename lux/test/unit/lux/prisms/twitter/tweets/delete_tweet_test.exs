defmodule Lux.Prisms.Twitter.Tweets.DeleteTweetTest do
  @moduledoc """
  Test suite for the DeleteTweet prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.DeleteTweet

  @tweet_id "1234567890123456789"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a tweet" do
      Req.Test.expect(DeleteTweet, fn conn ->
        assert conn.method == "DELETE"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"deleted" => true}
        }))
      end)

      assert {:ok, %{deleted: true}} = DeleteTweet.handler(
        %{tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles tweet not found" do
      Req.Test.expect(DeleteTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "title" => "Not Found Error"
        }))
      end)

      assert {:error, %{title: "Not Found"}} = DeleteTweet.handler(
        %{tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles unauthorized error" do
      Req.Test.expect(DeleteTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{}))
      end)

      assert {:error, %{title: "Unauthorized"}} = DeleteTweet.handler(
        %{tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles rate limit error" do
      Req.Test.expect(DeleteTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{}))
      end)

      assert {:error, %{title: "Rate Limited"}} = DeleteTweet.handler(
        %{tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles forbidden error" do
      Req.Test.expect(DeleteTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "You can only delete your own tweets"
        }))
      end)

      assert {:error, %{title: "Forbidden"}} = DeleteTweet.handler(
        %{tweet_id: @tweet_id},
        @agent
      )
    end
  end
end

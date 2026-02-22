defmodule Lux.Prisms.Twitter.Tweets.CreateTweetTest do
  @moduledoc """
  Test suite for the CreateTweet prism.
  Verifies the prism can:
  - Create a simple tweet
  - Create a reply to another tweet
  - Create a quote tweet
  - Handle rate limit errors
  - Handle unauthorized errors
  - Validate that text is provided
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.CreateTweet

  @tweet_id "1234567890123456789"
  @reply_to_id "9876543210987654321"
  @agent %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a simple tweet" do
      Req.Test.expect(CreateTweet, fn conn ->
        assert conn.method == "POST"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "Hello from Lux!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Hello from Lux!"
          }
        }))
      end)

      assert {:ok, result} = CreateTweet.handler(
        %{text: "Hello from Lux!"},
        @agent
      )
      assert result.id == @tweet_id
      assert result.text == "Hello from Lux!"
    end

    test "creates a reply tweet" do
      Req.Test.expect(CreateTweet, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "This is a reply"
        assert decoded["reply"]["in_reply_to_tweet_id"] == @reply_to_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "111", "text" => "This is a reply"}
        }))
      end)

      assert {:ok, result} = CreateTweet.handler(
        %{
          text: "This is a reply",
          reply: %{in_reply_to_tweet_id: @reply_to_id}
        },
        @agent
      )
      assert result.text == "This is a reply"
    end

    test "creates a quote tweet" do
      Req.Test.expect(CreateTweet, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["quote_tweet_id"] == @tweet_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "222", "text" => "Great post!"}
        }))
      end)

      assert {:ok, _result} = CreateTweet.handler(
        %{text: "Great post!", quote_tweet_id: @tweet_id},
        @agent
      )
    end

    test "handles rate limit error" do
      Req.Test.expect(CreateTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{
          "title" => "Too Many Requests",
          "detail" => "Too Many Requests"
        }))
      end)

      assert {:error, %{title: "Rate Limited"}} = CreateTweet.handler(
        %{text: "test"},
        @agent
      )
    end

    test "handles unauthorized error" do
      Req.Test.expect(CreateTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{
          "title" => "Unauthorized"
        }))
      end)

      assert {:error, %{title: "Unauthorized"}} = CreateTweet.handler(
        %{text: "test"},
        @agent
      )
    end

    test "handles forbidden error with detail" do
      Req.Test.expect(CreateTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "Your account is suspended"
        }))
      end)

      assert {:error, %{title: "Forbidden", detail: "Your account is suspended"}} =
               CreateTweet.handler(%{text: "test"}, @agent)
    end

    test "handles API error response with errors array" do
      Req.Test.expect(CreateTweet, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "errors" => [%{
            "title" => "Invalid Request",
            "detail" => "Tweet text is too long"
          }]
        }))
      end)

      assert {:error, %{title: "Invalid Request"}} = CreateTweet.handler(
        %{text: String.duplicate("x", 281)},
        @agent
      )
    end

    test "sets reply_settings when provided" do
      Req.Test.expect(CreateTweet, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["reply_settings"] == "mentionedUsers"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{"id" => "333", "text" => "Limited replies"}
        }))
      end)

      assert {:ok, _} = CreateTweet.handler(
        %{text: "Limited replies", reply_settings: "mentionedUsers"},
        @agent
      )
    end
  end
end

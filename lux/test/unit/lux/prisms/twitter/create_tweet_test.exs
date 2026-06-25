defmodule Lux.Prisms.Twitter.CreateTweetTest do
  @moduledoc """
  Test suite for the CreateTweet prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.CreateTweet
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/tweets"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["text"] == "Hello, world!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => "1234567890123456789",
            "text" => "Hello, world!",
            "created_at" => "2026-01-15T12:00:00.000Z",
            "author_id" => "987654321"
          }
        }))
      end)

      assert {:ok, %{id: "1234567890123456789", text: "Hello, world!"}} =
               CreateTweet.handler(%{text: "Hello, world!"}, @agent_ctx)
    end

    test "successfully creates a reply tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["text"] == "Great point!"
        assert parsed["reply"]["in_reply_to_tweet_id"] == "1111111111111111111"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => "2222222222222222222", "text" => "Great point!"}
        }))
      end)

      assert {:ok, %{id: "2222222222222222222"}} =
               CreateTweet.handler(%{
                 text: "Great point!",
                 reply_to_tweet_id: "1111111111111111111"
               }, @agent_ctx)
    end

    test "successfully creates a tweet with media" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["text"] == "Check this out!"
        assert parsed["media"]["media_ids"] == ["media_abc123"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"id" => "3333333333333333333", "text" => "Check this out!"}
        }))
      end)

      assert {:ok, %{id: "3333333333333333333"}} =
               CreateTweet.handler(%{
                 text: "Check this out!",
                 media_ids: ["media_abc123"]
               }, @agent_ctx)
    end

    test "rejects tweet exceeding 280 characters" do
      long_text = String.duplicate("a", 281)

      assert {:error, "Tweet text exceeds 280 character limit (got 281)"} =
               CreateTweet.handler(%{text: long_text}, @agent_ctx)
    end

    test "rejects missing text" do
      assert {:error, "Missing or invalid text"} =
               CreateTweet.handler(%{}, @agent_ctx)
    end

    test "handles Twitter API error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "errors" => [%{"message" => "Your tweet looks repetitive", "label" => "repetitive_twitter"}]
        }))
      end)

      assert {:error, {403, "Your tweet looks repetitive"}} =
               CreateTweet.handler(%{text: "Repeated text"}, @agent_ctx)
    end
  end
end

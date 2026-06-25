defmodule Lux.Prisms.Twitter.GetTweetByIdTest do
  @moduledoc """
  Test suite for the GetTweetById prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.GetTweetById
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}
  @tweet_id "9876543210987654321"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully fetches tweet by ID" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/tweets/#{@tweet_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Hello, world!",
            "author_id" => "123456789",
            "created_at" => "2026-01-15T12:00:00.000Z",
            "public_metrics" => %{
              "retweet_count" => 10,
              "reply_count" => 5,
              "like_count" => 100,
              "quote_count" => 2
            }
          }
        }))
      end)

      assert {:ok, %{id: ^@tweet_id, text: "Hello, world!"}} =
               GetTweetById.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end

    test "handles tweet not found" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Could not find Tweet with id: #{@tweet_id}"}]
        }))
      end)

      assert {:error, {404, "Could not find Tweet with id: #{@tweet_id}"}} =
               GetTweetById.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end

    test "rejects missing tweet_id" do
      assert {:error, "Missing or invalid tweet_id"} =
               GetTweetById.handler(%{}, @agent_ctx)
    end
  end
end

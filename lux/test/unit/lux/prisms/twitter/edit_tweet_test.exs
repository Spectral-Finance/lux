defmodule Lux.Prisms.Twitter.EditTweetTest do
  @moduledoc """
  Test suite for the EditTweet prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.EditTweet
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}
  @tweet_id "1234567890123456789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully edits a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/tweets/#{@tweet_id}"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        assert parsed["text"] == "Updated tweet text"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => "Updated tweet text"
          }
        }))
      end)

      assert {:ok, %{id: ^@tweet_id, text: "Updated tweet text"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "Updated tweet text"}, @agent_ctx)
    end

    test "rejects tweet exceeding 280 characters" do
      long_text = String.duplicate("a", 281)

      assert {:error, "Tweet text exceeds 280 character limit"} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: long_text}, @agent_ctx)
    end

    test "handles 403 forbidden on edit" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "errors" => [%{"message" => "Not authorized to edit this tweet"}]
        }))
      end)

      assert {:error, {403, "Not authorized to edit this tweet"}} =
               EditTweet.handler(%{tweet_id: @tweet_id, text: "New text"}, @agent_ctx)
    end

    test "rejects missing required fields" do
      assert {:error, "Missing or invalid tweet_id"} =
               EditTweet.handler(%{text: "text"}, @agent_ctx)

      assert {:error, "Missing or invalid text"} =
               EditTweet.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end
  end
end

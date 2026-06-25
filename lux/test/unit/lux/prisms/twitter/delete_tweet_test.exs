defmodule Lux.Prisms.Twitter.DeleteTweetTest do
  @moduledoc """
  Test suite for the DeleteTweet prism.
  """

  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.DeleteTweet
  alias Lux.Integrations.Telegram.Client, as: TelegramClient

  @agent_ctx %{name: "TestAgent"}
  @tweet_id "1234567890123456789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully deletes a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/tweets/#{@tweet_id}"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"deleted" => true}
        }))
      end)

      assert {:ok, %{deleted: true, tweet_id: ^@tweet_id}} =
               DeleteTweet.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end

    test "handles deletion failure" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{"deleted" => false}
        }))
      end)

      assert {:error, "Failed to delete tweet #{@tweet_id}"} =
               DeleteTweet.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end

    test "handles 404 not found" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "errors" => [%{"message" => "Could not find Tweet with id: #{@tweet_id}"}]
        }))
      end)

      assert {:error, {404, "Could not find Tweet with id: #{@tweet_id}"}} =
               DeleteTweet.handler(%{tweet_id: @tweet_id}, @agent_ctx)
    end

    test "rejects missing tweet_id" do
      assert {:error, "Missing or invalid tweet_id"} =
               DeleteTweet.handler(%{}, @agent_ctx)
    end
  end
end

defmodule Lux.Prisms.Twitter.Tweets.CreateTweetTest do
  @moduledoc """
  Test suite for the CreateTweet module.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.Tweets.CreateTweet

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["text"] == "Hello from Lux!"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => "1234567890",
            "text" => "Hello from Lux!"
          }
        }))
      end)

      assert {:ok, %{
        created: true,
        tweet_id: "1234567890",
        text: "Hello from Lux!"
      }} = CreateTweet.handler(
        %{text: "Hello from Lux!"},
        @agent_ctx
      )
    end

    test "handles missing text parameter" do
      assert {:error, "Missing or invalid text"} = CreateTweet.handler(
        %{},
        @agent_ctx
      )
    end

    test "handles API error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "title" => "Forbidden",
          "detail" => "Not allowed to create tweets"
        }))
      end)

      assert {:error, _} = CreateTweet.handler(
        %{text: "Test tweet"},
        @agent_ctx
      )
    end
  end
end

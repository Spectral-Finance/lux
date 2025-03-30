defmodule Lux.Prisms.Twitter.PostTweetTest do
  @moduledoc """
  Test suite for the PostTweet prism module.

  These tests verify the prism's ability to:
  - Post tweets to Twitter
  - Handle Twitter API errors appropriately
  - Validate input/output schemas
  - Support reply functionality

  The tests use a Twitter API client mock to simulate API interactions.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.PostTweet
  alias Lux.Test.Mocks.TwitterClientMock

  @tweet_text "This is a test tweet from Lux"
  @tweet_id "1234567890"
  @reply_to_id "9876543210"
  @agent_ctx %{name: "TestAgent"}

  setup do
    # Set up the TwitterClientMock
    Application.put_env(:lux, Lux.Integrations.Twitter.Client, plug: {Req.Test, TwitterClientMock})
    # Provide a test token
    Application.put_env(:lux, :twitter_test_token, "test-twitter-token")

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully posts a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body) == %{"text" => @tweet_text}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => @tweet_text
          }
        }))
      end)

      assert {:ok, %{
        id: @tweet_id,
        text: @tweet_text
      }} = PostTweet.handler(
        %{
          text: @tweet_text,
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully posts a reply tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        payload = Jason.decode!(body)
        assert payload["text"] == @tweet_text
        assert payload["reply"]["in_reply_to_tweet_id"] == @reply_to_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => @tweet_text
          }
        }))
      end)

      assert {:ok, %{
        id: @tweet_id,
        text: @tweet_text
      }} = PostTweet.handler(
        %{
          text: @tweet_text,
          reply_to: @reply_to_id,
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Twitter API error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "detail" => "Not authorized to post tweets"
        }))
      end)

      assert {:error, {403, "Not authorized to post tweets"}} = PostTweet.handler(
        %{
          text: @tweet_text,
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end

    test "validates input parameters" do
      assert {:error, "Missing or invalid text"} = PostTweet.handler(
        %{
          text: "",
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )

      assert {:error, "Missing or invalid text"} = PostTweet.handler(
        %{
          plug: {Req.Test, TwitterClientMock}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PostTweet.view()
      assert prism.input_schema.required == ["text"]
      assert Map.has_key?(prism.input_schema.properties, :text)
      assert Map.has_key?(prism.input_schema.properties, :reply_to)
      assert Map.has_key?(prism.input_schema.properties, :media_ids)
    end

    test "validates output schema" do
      prism = PostTweet.view()
      assert prism.output_schema.required == ["id", "text"]
      assert Map.has_key?(prism.output_schema.properties, :id)
      assert Map.has_key?(prism.output_schema.properties, :text)
    end
  end
end

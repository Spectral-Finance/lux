defmodule Lux.Prisms.Twitter.GetTweetTest do
  @moduledoc """
  Test suite for the GetTweet prism module.

  These tests verify the prism's ability to:
  - Retrieve tweets from Twitter by ID
  - Handle expanded fields like author and metrics
  - Process Twitter API errors appropriately
  - Validate input/output schemas

  The tests use a Twitter API client mock to simulate API interactions.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Twitter.GetTweet
  alias Lux.Test.Mocks.TwitterClientMock

  @tweet_id "1234567890"
  @tweet_text "This is a test tweet from Lux"
  @author_id "9876543210"
  @author_username "test_user"
  @agent_ctx %{name: "TestAgent"}

  setup do
    # Set up the TwitterClientMock
    Application.put_env(:lux, Lux.Integrations.Twitter.Client, plug: {Req.Test, __MODULE__})
    # Provide a test token
    Application.put_env(:lux, :twitter_test_token, "test-twitter-token")

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully retrieves a tweet" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/#{@tweet_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        # Check for required tweet fields in query parameters
        query = URI.decode_query(conn.query_string)
        assert Map.has_key?(query, "tweet.fields")
        assert String.contains?(query["tweet.fields"], "author_id")
        assert String.contains?(query["tweet.fields"], "created_at")
        assert String.contains?(query["tweet.fields"], "public_metrics")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => @tweet_text,
            "created_at" => "2023-07-22T15:30:00.000Z"
          }
        }))
      end)

      assert {:ok, %{
        id: @tweet_id,
        text: @tweet_text,
        created_at: "2023-07-22T15:30:00.000Z"
      }} = GetTweet.handler(
        %{
          id: @tweet_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "retrieves a tweet with author expansion" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/#{@tweet_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        # Check for expansions and user fields in query parameters
        query = URI.decode_query(conn.query_string)
        assert Map.has_key?(query, "expansions")
        assert query["expansions"] == "author_id"
        assert Map.has_key?(query, "user.fields")
        assert String.contains?(query["user.fields"], "id")
        assert String.contains?(query["user.fields"], "username")

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => @tweet_text,
            "author_id" => @author_id
          },
          "includes" => %{
            "users" => [
              %{
                "id" => @author_id,
                "name" => "Test User",
                "username" => @author_username
              }
            ]
          }
        }))
      end)

      assert {:ok, %{
        id: @tweet_id,
        text: @tweet_text,
        author: %{
          id: @author_id,
          name: "Test User",
          username: @author_username
        }
      }} = GetTweet.handler(
        %{
          id: @tweet_id,
          expansions: ["author_id"],
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "retrieves a tweet with metrics" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/#{@tweet_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "data" => %{
            "id" => @tweet_id,
            "text" => @tweet_text,
            "public_metrics" => %{
              "retweet_count" => 10,
              "like_count" => 25,
              "reply_count" => 5
            }
          }
        }))
      end)

      assert {:ok, %{
        id: @tweet_id,
        text: @tweet_text,
        metrics: %{
          retweet_count: 10,
          like_count: 25,
          reply_count: 5
        }
      }} = GetTweet.handler(
        %{
          id: @tweet_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "handles Twitter API error" do
      Req.Test.expect(TwitterClientMock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/#{@tweet_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-twitter-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{
          "detail" => "Tweet not found"
        }))
      end)

      assert {:error, {404, "Tweet not found"}} = GetTweet.handler(
        %{
          id: @tweet_id,
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end

    test "validates input parameters" do
      assert {:error, "Missing or invalid id"} = GetTweet.handler(
        %{
          id: "",
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )

      assert {:error, "Missing or invalid id"} = GetTweet.handler(
        %{
          plug: {Req.Test, __MODULE__}
        },
        @agent_ctx
      )
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = GetTweet.view()
      assert prism.input_schema.required == ["id"]
      assert Map.has_key?(prism.input_schema.properties, :id)
      assert Map.has_key?(prism.input_schema.properties, :expansions)
    end

    test "validates output schema" do
      prism = GetTweet.view()
      assert prism.output_schema.required == ["id", "text"]
      assert Map.has_key?(prism.output_schema.properties, :id)
      assert Map.has_key?(prism.output_schema.properties, :text)
      assert Map.has_key?(prism.output_schema.properties, :author)
      assert Map.has_key?(prism.output_schema.properties, :created_at)
      assert Map.has_key?(prism.output_schema.properties, :metrics)
    end
  end
end

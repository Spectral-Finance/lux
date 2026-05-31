defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter
  alias Lux.Integrations.Twitter.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "configuration" do
    test "uses the configured API URL for request paths" do
      previous = Application.get_env(:lux, Twitter)

      try do
        Application.put_env(:lux, Twitter, api_url: "https://api.twitter.com")

        Req.Test.expect(__MODULE__, fn conn ->
          assert conn.method == "GET"
          assert conn.request_path == "/2/tweets/search/recent"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => []}))
        end)

        assert {:ok, %{"data" => []}} =
                 Client.search_recent("lux", %{}, %{
                   access_token: "access-1",
                   plug: {Req.Test, __MODULE__}
                 })
      after
        if previous do
          Application.put_env(:lux, Twitter, previous)
        else
          Application.delete_env(:lux, Twitter)
        end
      end
    end
  end

  describe "OAuth 2.0 PKCE" do
    test "builds RFC-compatible challenge" do
      pkce = Client.pkce_pair("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

      assert pkce.verifier == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      assert pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
      assert pkce.method == "S256"
    end

    test "builds authorization URL with default scopes" do
      url =
        Client.authorization_url(%{
          client_id: "client-1",
          redirect_uri: "https://example.com/callback",
          state: "state-1",
          code_verifier: "verifier-1"
        })

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert uri.host == "x.com"
      assert uri.path == "/i/oauth2/authorize"
      assert query["client_id"] == "client-1"
      assert query["redirect_uri"] == "https://example.com/callback"
      assert query["response_type"] == "code"
      assert query["scope"] =~ "tweet.write"
      assert query["scope"] =~ "media.write"
      assert query["code_challenge_method"] == "S256"
    end

    test "exchanges authorization code with form body and optional basic auth" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/oauth2/token"

        assert Plug.Conn.get_req_header(conn, "authorization") == [
                 "Basic Y2xpZW50LTE6c2VjcmV0LTE="
               ]

        assert Plug.Conn.get_req_header(conn, "content-type") == [
                 "application/x-www-form-urlencoded"
               ]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        form = URI.decode_query(body)

        assert form["grant_type"] == "authorization_code"
        assert form["client_id"] == "client-1"
        assert form["code"] == "code-1"
        assert form["code_verifier"] == "verifier-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "access-1"}))
      end)

      assert {:ok, %{"access_token" => "access-1"}} =
               Client.token_request(:authorization_code, %{
                 client_id: "client-1",
                 client_secret: "secret-1",
                 redirect_uri: "https://example.com/callback",
                 code: "code-1",
                 code_verifier: "verifier-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "preflights grant-specific token request fields" do
      assert {:error, {:missing_required_fields, [:code, :redirect_uri, :code_verifier]}} =
               Client.token_request(:authorization_code, %{client_id: "client-1"})

      assert {:error, {:missing_required_fields, [:refresh_token]}} =
               Client.token_request(:refresh_token, %{client_id: "client-1"})
    end
  end

  describe "tweets" do
    test "rejects write operations without a user access token" do
      assert {:error, :access_token_required} =
               Client.create_tweet(%{text: "hello"}, %{bearer_token: "app-only"})

      assert {:error, :access_token_required} =
               Client.delete_tweet("tweet-1", %{bearer_token: "app-only"})
    end

    test "creates a post with reply, quote, media, and edit options" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer access-1"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        assert json["text"] == "updated text"
        assert json["reply"]["in_reply_to_tweet_id"] == "parent-1"
        assert json["quote_tweet_id"] == "quote-1"
        assert json["media"]["media_ids"] == ["media-1"]
        assert json["edit_options"]["previous_post_id"] == "old-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "tweet-1"}}} =
               Client.edit_tweet(
                 "old-1",
                 %{
                   text: "updated text",
                   reply_to_tweet_id: "parent-1",
                   quote_tweet_id: "quote-1",
                   media_ids: ["media-1"]
                 },
                 %{access_token: "access-1", plug: {Req.Test, __MODULE__}}
               )
    end

    test "creates a thread by chaining replies" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.expect(__MODULE__, 2, fn conn ->
        index = Agent.get_and_update(counter, fn value -> {value, value + 1} end)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        if index == 0 do
          assert json["text"] == "first"
          refute Map.has_key?(json, "reply")
        else
          assert json["text"] == "second"
          assert json["reply"]["in_reply_to_tweet_id"] == "tweet-1"
        end

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(201, Jason.encode!(%{"data" => %{"id" => "tweet-#{index + 1}"}}))
      end)

      assert {:ok, [%{"data" => %{"id" => "tweet-1"}}, %{"data" => %{"id" => "tweet-2"}}]} =
               Client.create_thread(["first", "second"], %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "thread errors include already published posts" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        if json["text"] == "first" do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(201, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(403, Jason.encode!(%{"detail" => "missing scope"}))
        end
      end)

      assert {:error,
              {:partial_thread_failure,
               %{
                 reason: {403, "missing scope"},
                 published: [%{"data" => %{"id" => "tweet-1"}}]
               }}} =
               Client.create_thread(["first", "second"], %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "deletes and looks up tweets with query params" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/2/tweets/tweet-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"deleted" => true}}))
      end)

      assert {:ok, %{"data" => %{"deleted" => true}}} =
               Client.delete_tweet("tweet-1", %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/tweet-1"
        assert conn.query_string == "tweet.fields=created_at%2Cpublic_metrics"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "tweet-1"}}} =
               Client.get_tweet("tweet-1", %{tweet_fields: ["created_at", "public_metrics"]}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end
  end

  describe "users, search, media, and rate limits" do
    test "reads authenticated user and manages follows" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/me"
        assert conn.query_string == "user.fields=username"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "user-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "user-1"}}} =
               Client.get_me(%{user_fields: ["username"]}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/users/user-1/following"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(body)["target_user_id"] == "user-2"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"following" => true}}))
      end)

      assert {:ok, %{"data" => %{"following" => true}}} =
               Client.follow_user("user-1", "user-2", %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "searches recent tweets and exposes rate limit headers" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/search/recent"
        assert conn.query_string == "max_results=10&query=lux"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "300")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "299")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1770000000")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok,
              %{
                body: %{"data" => []},
                rate_limit: %{
                  limit: 300,
                  remaining: 299,
                  reset: 1_770_000_000,
                  reset_at: ~U[2026-02-02 02:40:00Z],
                  rate_limited?: false
                }
              }} =
               Client.search_recent("lux", %{max_results: 10}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__},
                 with_rate_limit: true
               })
    end

    test "returns structured rate limit errors" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/search/recent"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "300")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "0")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1770000000")
        |> Plug.Conn.put_resp_header("retry-after", "900")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"title" => "Too Many Requests"}))
      end)

      assert {:error,
              {:rate_limited,
               %{
                 body: %{"title" => "Too Many Requests"},
                 rate_limit: %{
                   limit: 300,
                   remaining: 0,
                   reset: 1_770_000_000,
                   reset_at: ~U[2026-02-02 02:40:00Z],
                   retry_after: 900,
                   rate_limited?: true
                 }
               }}} =
               Client.search_recent("lux", %{}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "reads followers and following for user profile management" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/user-1/followers"
        assert conn.query_string == "max_results=10&user.fields=username"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => [%{"id" => "follower-1"}]}))
      end)

      assert {:ok, %{"data" => [%{"id" => "follower-1"}]}} =
               Client.get_followers(
                 "user-1",
                 %{max_results: 10, user_fields: ["username"]},
                 %{access_token: "access-1", plug: {Req.Test, __MODULE__}}
               )

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/user-1/following"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => [%{"id" => "following-1"}]}))
      end)

      assert {:ok, %{"data" => [%{"id" => "following-1"}]}} =
               Client.get_following("user-1", %{}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "initializes chunked media upload with the documented v2 endpoint" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/media/upload/initialize"
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["total_bytes"] == 1024
        assert json["media_type"] == "video/mp4"
        assert json["media_category"] == "tweet_video"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(202, Jason.encode!(%{"data" => %{"id" => "media-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "media-1"}}} =
               Client.media_upload(
                 :init,
                 %{total_bytes: 1024, media_type: "video/mp4", media_category: "tweet_video"},
                 %{access_token: "access-1", plug: {Req.Test, __MODULE__}}
               )
    end

    test "appends and finalizes media uploads with documented media id paths" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/media/upload/media-1/append"
        assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type =~ "multipart/form-data"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "segment_index"
        refute body =~ "media_id"
        refute body =~ "APPEND"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"expires_at" => 1_770_000_000}}))
      end)

      assert {:ok, %{"data" => %{"expires_at" => 1_770_000_000}}} =
               Client.media_upload(
                 :append,
                 %{media_id: "media-1", segment_index: 0, media: "bytes"},
                 %{access_token: "access-1", plug: {Req.Test, __MODULE__}}
               )

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/media/upload/media-1/finalize"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "media-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "media-1"}}} =
               Client.media_upload(:finalize, %{media_id: "media-1"}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "checks media upload status with the documented media_id query" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/media/upload"
        assert conn.query_string == "media_id=media-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "media-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "media-1"}}} =
               Client.media_upload(:status, %{media_id: "media-1"}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "preflights media id requirements for chunked upload follow-ups" do
      assert {:error, {:missing_required_fields, [:media_id]}} =
               Client.media_upload(:finalize, %{}, %{access_token: "access-1"})

      assert {:error, {:missing_required_fields, [:media_id, :media]}} =
               Client.media_upload(:append, %{}, %{access_token: "access-1"})
    end

    test "preserves rate-limit context on permission errors when requested" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "50")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "49")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1770000000")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"detail" => "missing required scope"}))
      end)

      assert {:error,
              %{
                status: 403,
                reason: "missing required scope",
                rate_limit: %{limit: 50, remaining: 49, reset: 1_770_000_000}
              }} =
               Client.create_tweet(%{text: "hello"}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__},
                 with_rate_limit: true
               })
    end

    test "rejects media and follow mutations without a user access token" do
      assert {:error, :access_token_required} =
               Client.media_upload(:init, %{total_bytes: 1024}, %{bearer_token: "app-only"})

      assert {:error, :access_token_required} =
               Client.follow_user("user-1", "user-2", %{bearer_token: "app-only"})

      assert {:error, :access_token_required} =
               Client.unfollow_user("user-1", "user-2", %{bearer_token: "app-only"})
    end
  end
end

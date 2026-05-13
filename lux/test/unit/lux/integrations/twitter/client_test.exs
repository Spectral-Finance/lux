defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter
  alias Lux.Integrations.Twitter.Client

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "OAuth 2.0 PKCE" do
    test "builds RFC-compatible challenge" do
      pkce = Client.pkce_pair("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

      assert pkce.verifier == "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      assert pkce.challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
      assert pkce.method == "S256"
    end

    test "builds authorization URL with defaults" do
      url =
        Client.authorization_url(%{
          client_id: "client-1",
          redirect_uri: "https://example.com/callback",
          state: "state-1",
          code_verifier: "verifier-1"
        })

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert uri.scheme == "https"
      assert uri.host == "x.com"
      assert uri.path == "/i/oauth2/authorize"
      assert query["response_type"] == "code"
      assert query["client_id"] == "client-1"
      assert query["redirect_uri"] == "https://example.com/callback"
      assert query["state"] == "state-1"
      assert query["scope"] =~ "tweet.write"
      assert query["code_challenge_method"] == "S256"
    end

    test "exchanges authorization code with form body and optional basic auth" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/oauth2/token"

        assert Plug.Conn.get_req_header(conn, "authorization") == [
                 "Basic Y2xpZW50LTE6c2VjcmV0LTE="
               ]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        form = URI.decode_query(body)

        assert form["grant_type"] == "authorization_code"
        assert form["client_id"] == "client-1"
        assert form["code"] == "code-1"
        assert form["code_verifier"] == "verifier-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "access_token" => "access-1",
            "refresh_token" => "refresh-1",
            "expires_in" => 7200
          })
        )
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
  end

  describe "posts" do
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
        |> Plug.Conn.send_resp(
          201,
          Jason.encode!(%{"data" => %{"id" => "tweet-1", "text" => "updated text"}})
        )
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

    test "creates a thread by replying to the previous tweet" do
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

    test "deletes and looks up tweets" do
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
        assert conn.query_string =~ "tweet.fields=created_at%2Cpublic_metrics"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
      end)

      assert {:ok, %{"data" => %{"id" => "tweet-1"}}} =
               Client.get_tweet(
                 "tweet-1",
                 %{tweet_fields: ["created_at", "public_metrics"]},
                 %{access_token: "access-1", plug: {Req.Test, __MODULE__}}
               )
    end
  end

  describe "users" do
    test "reads the authenticated user and manages follows" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/me"
        assert conn.query_string == "user.fields=username"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"data" => %{"id" => "user-1", "username" => "lux"}})
        )
      end)

      assert {:ok, %{"data" => %{"username" => "lux"}}} =
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

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/2/users/user-1/following/user-2"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"following" => false}}))
      end)

      assert {:ok, %{"data" => %{"following" => false}}} =
               Client.unfollow_user("user-1", "user-2", %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end
  end

  describe "media upload" do
    test "initializes and finalizes chunked media uploads" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/media/upload"
        assert [content_type] = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type =~ "multipart/form-data"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "INIT"
        assert body =~ "tweet_video"

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

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/media/upload"
        assert conn.query_string == "command=STATUS&media_id=media-1"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{"data" => %{"processing_info" => %{"state" => "succeeded"}}})
        )
      end)

      assert {:ok, %{"data" => %{"processing_info" => %{"state" => "succeeded"}}}} =
               Client.media_upload(:status, %{media_id: "media-1"}, %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end
  end

  describe "rate limits and errors" do
    test "returns rate-limit metadata on success when requested" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "300")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "299")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, %{body: %{"data" => []}, rate_limit: %{limit: 300, remaining: 299}}} =
               Client.request(:get, "/2/tweets", %{
                 access_token: "access-1",
                 with_rate_limit: true,
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "normalizes rate-limit errors" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-limit", "300")
        |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "0")
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(429, Jason.encode!(%{"detail" => "Too Many Requests"}))
      end)

      assert {:error, {:rate_limited, %{limit: 300, remaining: 0, reset: 1}}} =
               Client.request(:get, "/2/tweets", %{
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "parses rate limits and classifies common API errors" do
      assert %{limit: 15, remaining: 0, reset: 1} =
               Twitter.rate_limit(%{
                 "x-rate-limit-limit" => "15",
                 "x-rate-limit-remaining" => "0",
                 "x-rate-limit-reset" => "1"
               })

      assert Twitter.classify_error(401, %{"detail" => "bad token"}) == :invalid_token
      assert Twitter.classify_error(403, %{"detail" => "forbidden"}) == {:forbidden, "forbidden"}
      assert Twitter.classify_error(404, %{"detail" => "missing"}) == {:not_found, "missing"}
    end
  end

  describe "benchmark/2" do
    test "measures local helper cost without network calls" do
      result = Client.benchmark(fn -> Client.pkce_pair("verifier-1") end, 5)

      assert result.iterations == 5
      assert result.total_us >= 0
      assert result.average_us >= 0
    end
  end
end

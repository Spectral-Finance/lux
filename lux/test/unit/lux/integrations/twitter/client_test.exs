defmodule Lux.Integrations.Twitter.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Client

  describe "pkce_pair/1 and authorization_url/1" do
    test "builds deterministic PKCE challenges and authorization URLs" do
      verifier = "abcdefghijklmnopqrstuvwxyz1234567890"
      expected_challenge = Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false)

      assert Client.pkce_pair(verifier) == %{
               verifier: verifier,
               challenge: expected_challenge,
               method: "S256"
             }

      url =
        Client.authorization_url(%{
          client_id: "client-1",
          redirect_uri: "https://example.com/callback",
          state: "state-1",
          scope: "tweet.read tweet.write",
          code_verifier: verifier
        })

      assert String.starts_with?(url, "https://twitter.com/i/oauth2/authorize?")
      assert url =~ "response_type=code"
      assert url =~ "client_id=client-1"
      assert url =~ "code_challenge=#{URI.encode_www_form(expected_challenge)}"
      assert url =~ "code_challenge_method=S256"
    end
  end

  describe "token_request/2" do
    test "builds authorization code and refresh token request plans" do
      assert {:ok, exchange} =
               Client.token_request(:authorization_code, %{
                 code: "code-1",
                 redirect_uri: "https://example.com/callback",
                 client_id: "client-1",
                 code_verifier: "verifier"
               })

      assert exchange.method == :post
      assert exchange.endpoint == "/2/oauth2/token"
      assert exchange.payload.grant_type == "authorization_code"
      assert exchange.payload.code == "code-1"

      assert {:ok, refresh} =
               Client.token_request(:refresh_token, %{
                 refresh_token: "refresh-1",
                 client_id: "client-1"
               })

      assert refresh.payload.grant_type == "refresh_token"
      assert refresh.payload.refresh_token == "refresh-1"
    end
  end

  describe "tweet_request/2" do
    test "builds create, reply, quote, media, delete, and lookup plans" do
      assert {:ok, create} =
               Client.tweet_request(:create, %{
                 text: "hello",
                 reply_to_tweet_id: "parent-1",
                 quote_tweet_id: "quote-1",
                 media_ids: ["media-1"],
                 access_token: "token"
               })

      assert create.method == :post
      assert create.endpoint == "/2/tweets"
      assert create.headers == [{"Authorization", "Bearer token"}]
      assert create.payload.text == "hello"
      assert create.payload.reply == %{in_reply_to_tweet_id: "parent-1"}
      assert create.payload.quote_tweet_id == "quote-1"
      assert create.payload.media == %{media_ids: ["media-1"]}

      assert {:ok, delete} = Client.tweet_request(:delete, %{tweet_id: "tweet-1"})
      assert delete.method == :delete
      assert delete.endpoint == "/2/tweets/tweet-1"

      assert {:ok, lookup} =
               Client.tweet_request(:lookup, %{
                 tweet_id: "tweet-1",
                 tweet_fields: ["created_at", "public_metrics"]
               })

      assert lookup.method == :get
      assert lookup.endpoint == "/2/tweets/tweet-1?tweet_fields=created_at%2Cpublic_metrics"
    end
  end

  describe "user_request/2" do
    test "builds user lookup and relationship plans" do
      assert {:ok, me} = Client.user_request(:me, %{user_fields: ["username"]})
      assert me.endpoint == "/2/users/me?user_fields=username"

      assert {:ok, lookup} = Client.user_request(:lookup, %{user_id: "user-1"})
      assert lookup.endpoint == "/2/users/user-1"

      assert {:ok, follow} = Client.user_request(:follow, %{user_id: "user-1", target_user_id: "user-2"})
      assert follow.method == :post
      assert follow.endpoint == "/2/users/user-1/following"
      assert follow.payload == %{target_user_id: "user-2"}

      assert {:ok, unfollow} = Client.user_request(:unfollow, %{user_id: "user-1", target_user_id: "user-2"})
      assert unfollow.method == :delete
      assert unfollow.endpoint == "/2/users/user-1/following/user-2"
    end
  end

  describe "media_upload_request/2" do
    test "builds chunked media upload plans" do
      assert {:ok, init} =
               Client.media_upload_request(:init, %{
                 total_bytes: 1024,
                 media_type: "image/png",
                 media_category: "tweet_image"
               })

      assert init.endpoint == "/1.1/media/upload.json"
      assert init.payload.command == "INIT"

      assert {:ok, append} =
               Client.media_upload_request(:append, %{
                 media_id: "media-1",
                 segment_index: 0,
                 media_data: "base64"
               })

      assert append.payload.command == "APPEND"
      assert append.payload.segment_index == 0

      assert {:ok, finalize} = Client.media_upload_request(:finalize, %{media_id: "media-1"})
      assert finalize.payload == %{command: "FINALIZE", media_id: "media-1"}
    end
  end

  describe "rate_limit/1 and classify_error/2" do
    test "parses rate-limit headers and normalizes errors" do
      assert Client.rate_limit(%{
               "x-rate-limit-limit" => "300",
               "x-rate-limit-remaining" => "0",
               "x-rate-limit-reset" => "1800"
             }) == %{
               limit: 300,
               remaining: 0,
               reset_at: 1800,
               retry_after: nil,
               limited?: true
             }

      assert Client.classify_error(429, %{"detail" => "Too Many Requests"}) == %{
               status: 429,
               type: :rate_limited,
               retryable?: true,
               message: "Too Many Requests"
             }

      assert Client.classify_error(403, %{"title" => "Forbidden"}).retryable? == false
    end
  end
end

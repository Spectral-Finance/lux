defmodule Lux.Lenses.Twitter.TwitterLensesTest do
  @moduledoc """
  Unit tests for Twitter API v2 integration, OAuth 2.0 PKCE client, and lenses.
  """

  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter
  alias Lux.Integrations.Twitter.Client
  alias Lux.Lenses.Twitter.Media.UploadMedia
  alias Lux.Lenses.Twitter.Tweets.CreateTweet
  alias Lux.Lenses.Twitter.Tweets.DeleteTweet
  alias Lux.Lenses.Twitter.Tweets.SearchTweets
  alias Lux.Lenses.Twitter.Users.GetUserByUsername

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "Twitter OAuth 2.0 PKCE & Client" do
    test "generates valid S256 PKCE code_verifier and code_challenge pair" do
      pair = Client.generate_pkce_pair()
      assert is_binary(pair.code_verifier)
      assert is_binary(pair.code_challenge)
      assert pair.method == "S256"
      assert byte_size(pair.code_verifier) >= 43

      expected_challenge =
        :crypto.hash(:sha256, pair.code_verifier)
        |> Base.url_encode64(padding: false)

      assert pair.code_challenge == expected_challenge
    end

    test "exchanges authorization code for OAuth 2.0 access token" do
      plug = fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/oauth2/token"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "token_type" => "bearer",
            "expires_in" => 7200,
            "access_token" => "tw_oauth2_token_xyz",
            "scope" => "tweet.read tweet.write users.read offline.access",
            "refresh_token" => "tw_refresh_123"
          })
        )
      end

      assert {:ok, %{"access_token" => "tw_oauth2_token_xyz", "refresh_token" => "tw_refresh_123"}} =
               Client.exchange_oauth_token(
                 %{
                   "grant_type" => "authorization_code",
                   "code" => "auth_code_123",
                   "code_verifier" => "verifier_abc"
                 },
                 %{plug: plug}
               )
    end

    test "handles HTTP 429 rate limits and extracts x-rate-limit-reset header" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-rate-limit-reset", "1750000999")
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          Jason.encode!(%{"title" => "Too Many Requests", "detail" => "Too Many Requests"})
        )
      end

      assert {:error, {:rate_limited, %{reset_at: 1_750_000_999}}} =
               Client.request(:get, "/tweets/search/recent", %{
                 token: "test_token",
                 plug: plug,
                 retry: false
               })
    end

    test "handles HTTP 401 unauthorized response" do
      plug = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"title" => "Unauthorized"}))
      end

      assert {:error, :unauthorized} =
               Client.request(:get, "/users/me", %{
                 token: "invalid_token",
                 plug: plug,
                 retry: false
               })
    end

    test "interpolates path parameters and attaches Bearer header on Lens struct" do
      lens = DeleteTweet.view()
      updated = Twitter.add_auth_header(%{lens | params: %{"id" => "998877"}})

      assert updated.url == "https://api.twitter.com/2/tweets/998877"
      assert Enum.any?(updated.headers, fn {k, v} -> k == "Authorization" and String.starts_with?(v, "Bearer ") end)
    end
  end

  describe "CreateTweet lens" do
    test "successfully creates a tweet" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "1890001",
              "text" => "Hello Twitter from Lux!",
              "edit_history_tweet_ids" => ["1890001"]
            }
          })
        )
      end)

      assert {:ok, %{id: "1890001", text: "Hello Twitter from Lux!"}} =
               CreateTweet.focus(%{"text" => "Hello Twitter from Lux!"})
    end

    test "supports quote tweets and thread replies" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/2/tweets"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "1890002",
              "text" => "Thread reply #2"
            }
          })
        )
      end)

      assert {:ok, %{id: "1890002", text: "Thread reply #2"}} =
               CreateTweet.focus(%{
                 "text" => "Thread reply #2",
                 "reply" => %{"in_reply_to_tweet_id" => "1890001"}
               })
    end

    test "propagates API errors on invalid tweet creation" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          403,
          Jason.encode!(%{
            "errors" => [%{"message" => "You are not allowed to create a Tweet with duplicate content."}]
          })
        )
      end)

      assert {:error, %{"errors" => [%{"message" => _}]}} =
               CreateTweet.focus(%{"text" => "Duplicate tweet"})
    end
  end

  describe "DeleteTweet lens" do
    test "successfully deletes a tweet by ID" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/2/tweets/1890001"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => %{"deleted" => true}
          })
        )
      end)

      assert {:ok, %{deleted: true}} = DeleteTweet.focus(%{"id" => "1890001"})
    end

    test "validates schema requirements for DeleteTweet" do
      lens = DeleteTweet.view()
      assert lens.schema.required == ["id"]
      assert Map.has_key?(lens.schema.properties, :id)
    end
  end

  describe "SearchTweets lens" do
    test "searches recent tweets and normalizes results" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/tweets/search/recent"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "id" => "101",
                "text" => "Autonomous Elixir agents on Lux",
                "author_id" => "u1",
                "public_metrics" => %{"like_count" => 42}
              }
            ],
            "meta" => %{"result_count" => 1, "next_token" => "tok_next_2"}
          })
        )
      end)

      assert {:ok, %{tweets: [tweet], result_count: 1, next_token: "tok_next_2"}} =
               SearchTweets.focus(%{"query" => "Lux Elixir"})

      assert tweet.id == "101"
      assert tweet.public_metrics["like_count"] == 42
    end

    test "handles empty search results gracefully" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "meta" => %{"result_count" => 0}
          })
        )
      end)

      assert {:ok, %{tweets: [], result_count: 0, next_token: nil}} =
               SearchTweets.focus(%{"query" => "nonexistent_xyz_999"})
    end
  end

  describe "GetUserByUsername lens" do
    test "fetches user profile and public metrics by username" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/2/users/by/username/spectralfi"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "u_spectral",
              "username" => "spectralfi",
              "name" => "Spectral Finance",
              "description" => "Onchain Agent Economy",
              "public_metrics" => %{"followers_count" => 125_000}
            }
          })
        )
      end)

      assert {:ok, user} = GetUserByUsername.focus(%{"username" => "spectralfi"})
      assert user.id == "u_spectral"
      assert user.username == "spectralfi"
      assert user.public_metrics["followers_count"] == 125_000
    end

    test "returns error when user is not found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "errors" => [%{"detail" => "Could not find user with username: [ghost_user]."}]
          })
        )
      end)

      assert {:error, %{"errors" => _}} = GetUserByUsername.focus(%{"username" => "ghost_user"})
    end
  end

  describe "UploadMedia lens" do
    test "uploads base64 media and returns media_id_string" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/1.1/media/upload.json"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          200,
          Jason.encode!(%{
            "media_id" => 1_890_000_000_000_000_999,
            "media_id_string" => "1890000000000000999",
            "size" => 1024,
            "expires_after_secs" => 86_400
          })
        )
      end)

      assert {:ok, %{media_id_string: "1890000000000000999", size: 1024}} =
               UploadMedia.focus(%{
                 "media_data" => "base64_encoded_bytes",
                 "media_category" => "tweet_image"
               })
    end

    test "validates schema requirements for UploadMedia" do
      lens = UploadMedia.view()
      assert lens.schema.required == ["media_data"]
      assert Map.has_key?(lens.schema.properties, :media_data)
    end
  end
end

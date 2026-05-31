defmodule Lux.Prisms.Twitter.TweetsTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.Auth.BuildAuthorizationUrl
  alias Lux.Prisms.Twitter.Auth.ExchangeToken
  alias Lux.Prisms.Twitter.Tweets.CreateThread
  alias Lux.Prisms.Twitter.Tweets.CreateTweet
  alias Lux.Prisms.Twitter.Tweets.DeleteTweet
  alias Lux.Prisms.Twitter.Users.UnfollowUser

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "create tweet prism passes agent input to the Twitter client" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/2/tweets"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"text" => "hello"}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
    end)

    assert {:ok, %{"data" => %{"id" => "tweet-1"}}} =
             CreateTweet.handler(
               %{text: "hello", access_token: "access-1", plug: {Req.Test, __MODULE__}},
               %{}
             )
  end

  test "delete tweet prism validates required input" do
    assert {:error, "Missing tweet_id"} = DeleteTweet.handler(%{}, %{})
  end

  test "thread prism creates replies in order" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      json = Jason.decode!(body)

      id =
        if json["text"] == "one" do
          "tweet-1"
        else
          assert json["reply"]["in_reply_to_tweet_id"] == "tweet-1"
          "tweet-2"
        end

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(201, Jason.encode!(%{"data" => %{"id" => id}}))
    end)

    assert {:ok, [%{"data" => %{"id" => "tweet-1"}}, %{"data" => %{"id" => "tweet-2"}}]} =
             CreateThread.handler(
               %{texts: ["one", "two"], access_token: "access-1", plug: {Req.Test, __MODULE__}},
               %{}
             )
  end

  test "auth URL prism exposes verifier and challenge" do
    assert {:ok, %{authorization_url: url, code_verifier: verifier, code_challenge: challenge}} =
             BuildAuthorizationUrl.handler(
               %{
                 client_id: "client-1",
                 redirect_uri: "https://example.com/callback",
                 state: "state-1"
               },
               %{}
             )

    assert verifier
    assert challenge
    assert URI.parse(url).host == "x.com"
  end

  test "token exchange prism passes refresh token requests to client" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/2/oauth2/token"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert URI.decode_query(body)["grant_type"] == "refresh_token"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"access_token" => "access-2"}))
    end)

    assert {:ok, %{"access_token" => "access-2"}} =
             ExchangeToken.handler(
               %{
                 grant_type: "refresh_token",
                 client_id: "client-1",
                 refresh_token: "refresh-1",
                 plug: {Req.Test, __MODULE__}
               },
               %{}
             )
  end

  test "token exchange prism rejects unsupported grant types without raising" do
    assert {:error, {:unsupported_grant_type, "client_credentials"}} =
             ExchangeToken.handler(
               %{grant_type: "client_credentials", client_id: "client-1"},
               %{}
             )
  end

  test "unfollow user prism calls the user-management endpoint" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/2/users/user-1/following/user-2"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"following" => false}}))
    end)

    assert {:ok, %{"data" => %{"following" => false}}} =
             UnfollowUser.handler(
               %{
                 source_user_id: "user-1",
                 target_user_id: "user-2",
                 access_token: "access-1",
                 plug: {Req.Test, __MODULE__}
               },
               %{}
             )
  end
end

defmodule Lux.Lenses.TwitterTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.GetTweet
  alias Lux.Lenses.Twitter.GetFollowers
  alias Lux.Lenses.Twitter.GetFollowing
  alias Lux.Lenses.Twitter.GetMe
  alias Lux.Lenses.Twitter.GetUser
  alias Lux.Lenses.Twitter.SearchRecent

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  test "get tweet lens reads by id" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/tweets/tweet-1"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"id" => "tweet-1"}}))
    end)

    assert {:ok, %{"data" => %{"id" => "tweet-1"}}} =
             GetTweet.focus(%{
               tweet_id: "tweet-1",
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "get user lens supports username lookup" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/users/by/username/spectral"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => %{"username" => "spectral"}}))
    end)

    assert {:ok, %{"data" => %{"username" => "spectral"}}} =
             GetUser.focus(%{
               username: "spectral",
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "get me lens reads the authenticated profile" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/users/me"
      assert conn.query_string == "user.fields=username%2Cverified"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(
        200,
        Jason.encode!(%{"data" => %{"id" => "me", "username" => "spectral"}})
      )
    end)

    assert {:ok, %{"data" => %{"username" => "spectral"}}} =
             GetMe.focus(%{
               user_fields: ["username", "verified"],
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "search recent lens forwards query params" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/tweets/search/recent"
      assert conn.query_string == "max_results=10&query=lux"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => []}))
    end)

    assert {:ok, %{"data" => []}} =
             SearchRecent.focus(%{
               query: "lux",
               max_results: 10,
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })
  end

  test "search recent lens accepts string-key schema input with token and rate limit metadata" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/tweets/search/recent"
      assert conn.query_string == "max_results=10&query=lux"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer access-1"]

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
              rate_limit: %{limit: 300, remaining: 299}
            }} =
             SearchRecent.focus(%{
               "query" => "lux",
               "max_results" => 10,
               "access_token" => "access-1",
               "with_rate_limit" => true,
               "plug" => {Req.Test, __MODULE__}
             })
  end

  test "followers and following lenses expose user social graph reads" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/users/user-1/followers"
      assert conn.query_string == "max_results=5"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => [%{"id" => "follower-1"}]}))
    end)

    assert {:ok, %{"data" => [%{"id" => "follower-1"}]}} =
             GetFollowers.focus(%{
               user_id: "user-1",
               max_results: 5,
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/2/users/user-1/following"

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"data" => [%{"id" => "following-1"}]}))
    end)

    assert {:ok, %{"data" => [%{"id" => "following-1"}]}} =
             GetFollowing.focus(%{
               user_id: "user-1",
               access_token: "access-1",
               plug: {Req.Test, __MODULE__}
             })
  end
end

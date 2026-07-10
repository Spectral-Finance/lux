defmodule Lux.Integrations.Twitter.ClientTest do
  use ExUnit.Case, async: true
  
  alias Lux.Integrations.Twitter.Client

  setup do
    Application.put_env(:lux, Lux.Integrations.Twitter.Client, twitter_bearer_token: "test_token")
    Application.put_env(:lux, :api_keys, twitter_bearer_token: "test_token")
    on_exit(fn -> 
      Application.delete_env(:lux, Lux.Integrations.Twitter.Client) 
      Application.delete_env(:lux, :api_keys)
    end)
    :ok
  end

  test "create_tweet/2 posts a tweet" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"id" => "123", "text" => "Hello World"}})
    end)
    assert {:ok, %{"data" => %{"id" => "123"}}} = Client.create_tweet("Hello World", plug: TwitterClientTest)
  end

  test "delete_tweet/2 deletes a tweet" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"deleted" => true}})
    end)
    assert {:ok, %{"data" => %{"deleted" => true}}} = Client.delete_tweet("123", plug: TwitterClientTest)
  end

  test "edit_tweet/3 edits a tweet" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"edit_history_tweet_ids" => ["123", "124"]}})
    end)
    assert {:ok, %{"data" => %{"edit_history_tweet_ids" => ["123", "124"]}}} = Client.edit_tweet("123", "Edited", plug: TwitterClientTest)
  end

  test "reply_to_tweet/3 replies to a tweet" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"id" => "456"}})
    end)
    assert {:ok, %{"data" => %{"id" => "456"}}} = Client.reply_to_tweet("123", "Reply", plug: TwitterClientTest)
  end

  test "quote_tweet/3 quotes a tweet" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"id" => "789"}})
    end)
    assert {:ok, %{"data" => %{"id" => "789"}}} = Client.quote_tweet("123", "Quote", plug: TwitterClientTest)
  end

  test "create_thread/2 creates a thread" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      if Map.has_key?(payload, "reply") do
        Req.Test.json(conn, %{"data" => %{"id" => "2"}})
      else
        Req.Test.json(conn, %{"data" => %{"id" => "1"}})
      end
    end)
    assert {:ok, [%{"data" => %{"id" => "1"}}, %{"data" => %{"id" => "2"}}]} = Client.create_thread(["First", "Second"], plug: TwitterClientTest)
  end

  test "create_thread/2 handles error in middle of thread" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      if Map.has_key?(payload, "reply") do
        conn |> Plug.Conn.send_resp(400, "Error")
      else
        Req.Test.json(conn, %{"data" => %{"id" => "1"}})
      end
    end)
    assert {:error, {{400, "Error"}, [%{"data" => %{"id" => "1"}}]}} = Client.create_thread(["First", "Second"], plug: TwitterClientTest)
  end

  test "get_user_profile/2 fetches profile" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"id" => "999", "username" => "lux_user"}})
    end)
    assert {:ok, %{"data" => %{"id" => "999"}}} = Client.get_user_profile("lux_user", plug: TwitterClientTest)
  end

  test "send_dm/3 sends a dm" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"event_id" => "abc"}})
    end)
    assert {:ok, %{"data" => %{"event_id" => "abc"}}} = Client.send_dm("123", "Hello", plug: TwitterClientTest)
  end

  test "follow_user/3 follows user" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"following" => true, "pending_follow" => false}})
    end)
    assert {:ok, %{"data" => %{"following" => true}}} = Client.follow_user("111", "222", plug: TwitterClientTest)
  end

  test "unfollow_user/3 unfollows user" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"data" => %{"following" => false}})
    end)
    assert {:ok, %{"data" => %{"following" => false}}} = Client.unfollow_user("111", "222", plug: TwitterClientTest)
  end

  test "handle rate limits" do
    Req.Test.stub(TwitterRateLimitTest, fn conn ->
      conn
      |> Plug.Conn.put_resp_header("x-rate-limit-reset", "12345678")
      |> Plug.Conn.put_resp_header("x-rate-limit-limit", "15")
      |> Plug.Conn.put_resp_header("x-rate-limit-remaining", "0")
      |> Plug.Conn.send_resp(429, "Too Many Requests")
    end)

    assert {:error, :rate_limit_exceeded, %{limit: "15"}} = Client.create_tweet("Test", plug: TwitterRateLimitTest)
  end

  test "handle 401 unauthorized" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      conn |> Plug.Conn.send_resp(401, "Unauthorized")
    end)
    assert {:error, :unauthorized} = Client.create_tweet("Test", plug: TwitterClientTest)
  end

  test "handle API errors wrapped in 200 with errors object" do
    Req.Test.stub(TwitterClientTest, fn conn ->
      Req.Test.json(conn, %{"errors" => [%{"message" => "Invalid ID"}]})
    end)
    assert {:error, [%{"message" => "Invalid ID"}]} = Client.get_user_profile("invalid", plug: TwitterClientTest)
  end
end

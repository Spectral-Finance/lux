defmodule Lux.Integrations.Twitter.ClientTest do
  use ExUnit.Case
  import Mock
  alias Lux.Integrations.Twitter.Client

  setup do
    # Setting an environment variable for config if it's fetched at runtime
    Application.put_env(:lux, :api_keys, twitter_bearer: "test_token")
    :ok
  end

  test "create_tweet makes a post request" do
    with_mock Req, [post!: fn(_url, _opts) -> %{status: 201} end] do
      assert %{status: 201} = Client.create_tweet("Hello world")
      assert called Req.post!("https://api.twitter.com/2/tweets", :_)
    end
  end

  test "reply_to_tweet makes a post request with reply" do
    with_mock Req, [post!: fn(_url, _opts) -> %{status: 201} end] do
      assert %{status: 201} = Client.reply_to_tweet("123", "Hello reply")
      assert called Req.post!("https://api.twitter.com/2/tweets", :_)
    end
  end

  test "send_dm makes a post request" do
    with_mock Req, [post!: fn(_url, _opts) -> %{status: 201} end] do
      assert %{status: 201} = Client.send_dm("user123", "Hello DM")
      assert called Req.post!("https://api.twitter.com/2/dm_events", :_)
    end
  end

  test "follow_user makes a post request" do
    with_mock Req, [post!: fn(_url, _opts) -> %{status: 200} end] do
      assert %{status: 200} = Client.follow_user("user1", "user2")
      assert called Req.post!("https://api.twitter.com/2/users/user1/following", :_)
    end
  end

  test "unfollow_user makes a delete request" do
    with_mock Req, [delete!: fn(_url, _opts) -> %{status: 200} end] do
      assert %{status: 200} = Client.unfollow_user("user1", "user2")
      assert called Req.delete!("https://api.twitter.com/2/users/user1/following/user2", :_)
    end
  end
end

defmodule Lux.Lenses.Twitter.GetUserTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.GetUser
  alias Lux.Integrations.Twitter.Client, as: TwitterClient

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "focus/1" do
    test "fetches user by username" do
      Req.Test.stub(TwitterClient, fn conn ->
        assert conn.request_path == "/2/users/by/username/testuser"

        Req.Test.json(conn, %{
          "data" => %{
            "id" => "123", "name" => "Test User", "username" => "testuser",
            "description" => "Hi there", "created_at" => "2020-01-01T00:00:00Z",
            "verified" => true, "location" => "Earth", "url" => "https://example.com",
            "profile_image_url" => "https://pbs.twimg.com/photo.jpg",
            "public_metrics" => %{
              "followers_count" => 1000, "following_count" => 500,
              "tweet_count" => 5000, "listed_count" => 50
            }
          }
        })
      end)

      assert {:ok, user} = GetUser.focus(%{username: "testuser"})
      assert user.id == "123"
      assert user.username == "testuser"
      assert user.metrics.followers == 1000
    end

    test "fetches user by ID" do
      Req.Test.stub(TwitterClient, fn conn ->
        assert conn.request_path == "/2/users/456"
        Req.Test.json(conn, %{"data" => %{"id" => "456", "name" => "By ID", "username" => "byid"}})
      end)

      assert {:ok, user} = GetUser.focus(%{user_id: "456"})
      assert user.id == "456"
    end
  end
end

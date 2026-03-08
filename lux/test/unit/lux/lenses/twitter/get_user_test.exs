defmodule Lux.Lenses.Twitter.GetUserTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.GetUser

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "focus/1" do
    test "fetches user by username" do
      Req.Test.stub(GetUser, fn conn ->
        Req.Test.json(conn, %{
          "data" => %{
            "id" => "123",
            "name" => "Test User",
            "username" => "testuser",
            "description" => "Hello",
            "created_at" => "2020-01-01T00:00:00Z",
            "verified" => true,
            "location" => "Earth",
            "url" => "https://example.com",
            "profile_image_url" => "https://pbs.twimg.com/test.jpg",
            "public_metrics" => %{
              "followers_count" => 1000,
              "following_count" => 500,
              "tweet_count" => 5000,
              "listed_count" => 50
            }
          }
        })
      end)

      assert {:ok, user} = GetUser.focus(%{username: "testuser"})
      assert user.id == "123"
      assert user.username == "testuser"
      assert user.verified == true
      assert user.metrics.followers == 1000
      assert user.metrics.tweets == 5000
    end

    test "handles user not found" do
      Req.Test.stub(GetUser, fn conn ->
        Req.Test.json(conn, %{"errors" => [%{"detail" => "User not found"}]})
      end)

      assert {:error, "User not found"} = GetUser.focus(%{username: "nobody"})
    end
  end
end

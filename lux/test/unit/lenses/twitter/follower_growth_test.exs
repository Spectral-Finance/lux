defmodule Lux.Lenses.Twitter.Analytics.FollowerGrowthTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.Analytics.FollowerGrowth

  describe "before_focus/1" do
    test "uses ids param for user_id" do
      params = %{user_id: "12345"}
      result = FollowerGrowth.before_focus(params)

      assert Map.get(result, :ids) == "12345"
      refute Map.has_key?(result, :user_id)
    end

    test "uses usernames param for username" do
      params = %{username: "twitterdev"}
      result = FollowerGrowth.before_focus(params)

      assert Map.get(result, :usernames) == "twitterdev"
      refute Map.has_key?(result, :username)
    end

    test "adds user.fields" do
      params = %{user_id: "12345"}
      result = FollowerGrowth.before_focus(params)

      assert Map.has_key?(result, :"user.fields")
    end
  end

  describe "after_focus/1" do
    test "parses single user data" do
      body = %{
        "data" => %{
          "id" => "12345",
          "username" => "twitterdev",
          "name" => "Twitter Dev",
          "public_metrics" => %{
            "followers_count" => 50000,
            "following_count" => 1000,
            "tweet_count" => 3000,
            "listed_count" => 500
          },
          "verified" => true,
          "created_at" => "2020-01-01T00:00:00Z"
        }
      }

      {:ok, result} = FollowerGrowth.after_focus(body)

      assert result.user_metrics.user_id == "12345"
      assert result.user_metrics.followers == 50000
      assert result.user_metrics.verified == true
    end

    test "parses list of users" do
      body = %{
        "data" => [
          %{"id" => "1", "username" => "a", "public_metrics" => %{"followers_count" => 100}},
          %{"id" => "2", "username" => "b", "public_metrics" => %{"followers_count" => 200}}
        ]
      }

      {:ok, result} = FollowerGrowth.after_focus(body)
      assert result.count == 2
    end

    test "handles missing public_metrics gracefully" do
      body = %{"data" => %{"id" => "1", "username" => "test"}}

      {:ok, result} = FollowerGrowth.after_focus(body)
      assert result.user_metrics.followers == 0
    end
  end
end

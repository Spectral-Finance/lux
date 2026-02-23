defmodule Lux.Lenses.Twitter.Analytics.GetUserMetricsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.Analytics.GetUserMetrics

  describe "after_focus/1" do
    test "transforms user data with public metrics" do
      response = %{
        "data" => %{
          "id" => "123456789",
          "username" => "testuser",
          "name" => "Test User",
          "verified" => false,
          "created_at" => "2020-01-01T00:00:00.000Z",
          "public_metrics" => %{
            "followers_count" => 10_000,
            "following_count" => 500,
            "tweet_count" => 1_200,
            "listed_count" => 150
          }
        }
      }

      assert {:ok, result} = GetUserMetrics.after_focus(response)
      assert result.user_id == "123456789"
      assert result.username == "testuser"
      assert result.metrics.followers_count == 10_000
      assert result.metrics.following_count == 500
      assert result.metrics.tweet_count == 1_200
    end

    test "handles missing metrics with zeros" do
      response = %{"data" => %{"id" => "1", "username" => "user", "name" => "User"}}
      assert {:ok, result} = GetUserMetrics.after_focus(response)
      assert result.metrics.followers_count == 0
    end

    test "returns error for API errors" do
      response = %{"errors" => [%{"title" => "Not Found Error", "detail" => "User not found"}]}
      assert {:error, %{title: "Not Found Error"}} = GetUserMetrics.after_focus(response)
    end
  end
end

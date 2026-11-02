defmodule Lux.Community.YouTube.CommunityPostSchedulerTest do
  use ExUnit.Case, async: true

  alias Lux.Community.YouTube.CommunityPostScheduler

  describe "create_post/1" do
    test "creates valid text post" do
      {:ok, post} =
        CommunityPostScheduler.create_post(%{
          content: "Excited to announce our new live coding series tomorrow!",
          type: :text
        })

      assert post.type == :text
      assert post.status == :scheduled
      assert String.starts_with?(post.id, "post_")
    end

    test "creates valid poll post" do
      {:ok, post} =
        CommunityPostScheduler.create_post(%{
          content: "Which framework should we build next?",
          type: :poll,
          poll_options: ["Phoenix LiveView", "Next.js", "FastAPI"]
        })

      assert post.type == :poll
      assert length(post.poll_options) == 3
    end

    test "rejects poll with less than 2 options" do
      assert {:error, msg} =
               CommunityPostScheduler.create_post(%{
                 content: "Invalid poll",
                 type: :poll,
                 poll_options: ["Only one"]
               })

      assert String.contains?(msg, "at least 2 options")
    end

    test "rejects empty content" do
      assert {:error, msg} = CommunityPostScheduler.create_post(%{content: ""})
      assert String.contains?(msg, "cannot be empty")
    end
  end

  describe "recommend_optimal_window/1" do
    test "returns expected peak engagement time" do
      rec = CommunityPostScheduler.recommend_optimal_window("EST")
      assert rec.recommended_utc_hour == 15
      assert rec.expected_lift_percentage > 20.0
    end
  end
end

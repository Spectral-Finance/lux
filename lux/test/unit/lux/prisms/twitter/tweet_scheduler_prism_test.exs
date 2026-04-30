defmodule Lux.Prisms.Twitter.TweetSchedulerPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Twitter.TweetSchedulerPrism

  describe "run/1" do
    test "schedules tweet with required fields" do
      assert {:ok, result} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Check out our latest DeFi analysis!"
      })

      assert result[:scheduled_at] != nil
      assert result[:status] == "scheduled"
      assert result[:schedule_id] != nil
      assert result[:optimal_window] != nil
      assert result[:engagement_prediction] != nil
      assert result[:queue_position] != nil
    end

    test "schedules tweet with optimal_time" do
      {:ok, result} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Test tweet",
        optimal_time: "2024-06-15T10:00:00Z"
      })

      assert result[:scheduled_at] == "2024-06-15T10:00:00Z"
    end

    test "schedules tweet with scheduled_at" do
      {:ok, result} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Test tweet",
        scheduled_at: "2024-06-15T14:00:00Z"
      })

      assert result[:scheduled_at] == "2024-06-15T14:00:00Z"
    end

    test "respects priority for queue position" do
      {:ok, result_urgent} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Urgent tweet",
        priority: "urgent"
      })
      assert result_urgent[:queue_position] == 1

      {:ok, result_high} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "High priority tweet",
        priority: "high"
      })
      assert result_high[:queue_position] == 2

      {:ok, result_normal} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Normal tweet",
        priority: "normal"
      })
      assert result_normal[:queue_position] == 5

      {:ok, result_low} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Low priority tweet",
        priority: "low"
      })
      assert result_low[:queue_position] == 10
    end

    test "calculates optimal window based on content type" do
      {:ok, result_thread} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Thread content",
        content_type: "thread"
      })
      assert result_thread[:optimal_window][:duration_minutes] == 120

      {:ok, result_media} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Media content",
        content_type: "media"
      })
      assert result_media[:optimal_window][:duration_minutes] == 90

      {:ok, result_text} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Text content",
        content_type: "text"
      })
      assert result_text[:optimal_window][:duration_minutes] == 60
    end

    test "engagement prediction is between 0 and 1" do
      {:ok, result} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{
        content: "Test tweet with reasonable length for scoring",
        content_type: "text"
      })

      assert result[:engagement_prediction] >= 0.0
      assert result[:engagement_prediction] <= 1.0
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Twitter.TweetSchedulerPrism.__meta__(:name) == "Tweet Scheduler"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Twitter.TweetSchedulerPrism.__input_schema__()
      assert "content" in schema[:required]
    end

    test "generates unique schedule IDs" do
      {:ok, result1} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{content: "Tweet 1"})
      {:ok, result2} = Lux.Prisms.Twitter.TweetSchedulerPrism.run(%{content: "Tweet 2"})

      # Schedule IDs should be different (generated from random bytes)
      assert result1[:schedule_id] != result2[:schedule_id]
    end
  end
end

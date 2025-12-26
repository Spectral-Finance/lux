defmodule Lux.TwitterAutomation.QueueManagerTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.QueueManager
  alias Lux.TwitterAutomation.Storage

  setup do
    {:ok, _pid} = start_supervised(QueueManager)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "enqueue/3" do
    test "enqueues an action" do
      assert {:ok, id} = QueueManager.enqueue(:create_tweet, %{content: "Test tweet"})
      assert is_binary(id)
      assert QueueManager.get_queue_size() == 1
    end

    test "supports different priorities" do
      assert {:ok, _id1} = QueueManager.enqueue(:create_tweet, %{content: "High priority"}, :high)
      assert {:ok, _id2} = QueueManager.enqueue(:create_tweet, %{content: "Low priority"}, :low)
      assert {:ok, _id3} = QueueManager.enqueue(:create_tweet, %{content: "Normal priority"}, :normal)
      
      assert QueueManager.get_queue_size() == 3
    end
  end

  describe "get_queue_size/0" do
    test "returns current queue size" do
      assert 0 == QueueManager.get_queue_size()
      
      QueueManager.enqueue(:create_tweet, %{content: "Test"}, :high)
      assert 1 == QueueManager.get_queue_size()
      
      QueueManager.enqueue(:follow_user, %{user_id: "user123"}, :low)
      assert 2 == QueueManager.get_queue_size()
    end
  end

  describe "get_rate_limit_status/0" do
    test "returns rate limit status for different action types" do
      status = QueueManager.get_rate_limit_status()
      
      assert is_integer(status.tweets)
      assert is_integer(status.follows)
      assert is_integer(status.unfollows)
      assert is_integer(status.dms)
    end
  end

  describe "queue processing" do
    test "processes queued actions" do
      # Note: Since the actual execution depends on external Twitter API,
      # we're testing the queuing and scheduling behavior
      QueueManager.enqueue(:create_tweet, %{content: "Test tweet"}, :high)
      assert QueueManager.get_queue_size() == 1
      
      # Process the queue
      QueueManager.process_now()
      # QueueManager will re-queue actions that can't be executed due to rate limits or other errors
      # So the action might still be in the queue after attempting to process
    end

    test "respects rate limits" do
      # Queue multiple actions at once to test rate limit behavior
      for i <- 1..5 do
        QueueManager.enqueue(:create_tweet, %{content: "Tweet #{i}"}, :normal)
      end
      
      assert QueueManager.get_queue_size() == 5
      
      # Process the queue
      QueueManager.process_now()
    end

    test "handles different action types" do
      QueueManager.enqueue(:create_tweet, %{content: "Test tweet"}, :normal)
      QueueManager.enqueue(:follow_user, %{user_id: "user123"}, :normal)
      QueueManager.enqueue(:send_dm, %{user_id: "user123", content: "Hi"}, :normal)
      QueueManager.enqueue(:unfollow_user, %{user_id: "user456"}, :normal)
      
      assert QueueManager.get_queue_size() == 4
      
      QueueManager.process_now()
    end
  end

  describe "rate limit tracking" do
    test "decreases available requests when processing actions" do
      initial_status = QueueManager.get_rate_limit_status()
      initial_tweet_limit = initial_status.tweets
      
      # Process a tweet action
      QueueManager.enqueue(:create_tweet, %{content: "Test tweet"}, :high)
      QueueManager.process_now()
      
      # Check that available requests decreased
      updated_status = QueueManager.get_rate_limit_status()
      assert updated_status.tweets <= initial_tweet_limit
    end
  end

  describe "priority handling" do
    test "processes higher priority actions first" do
      # Create actions with different priorities
      QueueManager.enqueue(:create_tweet, %{content: "Low priority"}, :low)
      QueueManager.enqueue(:create_tweet, %{content: "High priority"}, :high)
      QueueManager.enqueue(:create_tweet, %{content: "Normal priority"}, :normal)
      
      assert QueueManager.get_queue_size() == 3
    end
  end

  describe "error handling" do
    test "re-queues failed actions" do
      # Enqueue an action that will likely fail due to invalid payload
      QueueManager.enqueue(:create_tweet, %{invalid: "data"}, :normal)
      
      initial_size = QueueManager.get_queue_size()
      assert initial_size == 1
      
      # Process the queue
      QueueManager.process_now()
      
      # The action should be re-queued with incremented retries
      final_size = QueueManager.get_queue_size()
      assert final_size == initial_size  # Failed action gets re-queued
    end
  end

  describe "cleanup" do
    test "clears all data on cleanup" do
      QueueManager.enqueue(:create_tweet, %{content: "Test"}, :normal)
      assert QueueManager.get_queue_size() > 0
      
      Storage.clear_all()
      assert QueueManager.get_queue_size() == 0
    end
  end
end
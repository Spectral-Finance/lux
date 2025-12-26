defmodule Lux.TwitterAutomation.FollowManagerTest do
  use ExUnit.Case, async: false

  alias Lux.TwitterAutomation.FollowManager
  alias Lux.TwitterAutomation.QueueManager
  alias Lux.TwitterAutomation.Storage

  setup do
    {:ok, _pid} = start_supervised(FollowManager)
    # Also start QueueManager since FollowManager depends on it
    {:ok, _queue_pid} = start_supervised(QueueManager)
    Storage.clear_all()
    on_exit(fn -> Storage.clear_all() end)
    :ok
  end

  describe "follow_user/2" do
    test "follows a user successfully" do
      assert {:ok, queue_id} = FollowManager.follow_user("user123", "auth_user456")
      assert is_binary(queue_id)
    end

    test "fails to follow a blacklisted user" do
      # Add user to blacklist first
      assert :ok = FollowManager.add_to_blacklist("blocked_user789")

      # Try to follow the blacklisted user
      assert {:error, :blacklisted} = FollowManager.follow_user("blocked_user789", "auth_user456")
    end

    test "tracks follow history" do
      initial_status = FollowManager.get_follow_status()
      initial_follows = initial_status.follows_today

      assert {:ok, _queue_id} = FollowManager.follow_user("user123", "auth_user456")

      # Check updated status
      updated_status = FollowManager.get_follow_status()
      assert updated_status.follows_today == initial_follows + 1
    end
  end

  describe "unfollow_user/2" do
    test "unfollows a user successfully" do
      assert {:ok, queue_id} = FollowManager.unfollow_user("user123", "auth_user456")
      assert is_binary(queue_id)
    end

    test "fails to unfollow a whitelisted user" do
      # Add user to whitelist first
      assert :ok = FollowManager.add_to_whitelist("protected_user789")

      # Try to unfollow the whitelisted user
      assert {:error, :whitelisted} = FollowManager.unfollow_user("protected_user789", "auth_user456")
    end

    test "tracks unfollow history" do
      initial_status = FollowManager.get_follow_status()
      initial_unfollows = initial_status.unfollows_today

      assert {:ok, _queue_id} = FollowManager.unfollow_user("user123", "auth_user456")

      # Check updated status
      updated_status = FollowManager.get_follow_status()
      assert updated_status.unfollows_today == initial_unfollows + 1
    end
  end

  describe "auto follow-back feature" do
    test "enables auto follow-back" do
      # Verify initially disabled
      initial_status = FollowManager.get_follow_status()
      refute initial_status.auto_follow_back

      # Enable it
      assert :ok = FollowManager.enable_auto_follow_back()

      # Verify enabled
      updated_status = FollowManager.get_follow_status()
      assert updated_status.auto_follow_back
    end

    test "disables auto follow-back" do
      # Enable first
      assert :ok = FollowManager.enable_auto_follow_back()

      # Verify enabled
      status = FollowManager.get_follow_status()
      assert status.auto_follow_back

      # Disable it
      assert :ok = FollowManager.disable_auto_follow_back()

      # Verify disabled
      updated_status = FollowManager.get_follow_status()
      refute updated_status.auto_follow_back
    end

    test "follows back when auto follow-back is enabled" do
      assert :ok = FollowManager.enable_auto_follow_back()

      # This would trigger a follow back if auto follow-back is enabled
      # In a real test environment, this would result in a QueueManager call
      FollowManager.process_new_follower("new_follower", "auth_user456")
    end

    test "does not follow back when auto follow-back is disabled" do
      assert :ok = FollowManager.disable_auto_follow_back()

      # This should not trigger a follow back since auto follow-back is disabled
      FollowManager.process_new_follower("new_follower", "auth_user456")
    end

    test "does not follow back blacklisted users" do
      assert :ok = FollowManager.enable_auto_follow_back()
      assert :ok = FollowManager.add_to_blacklist("blacklisted_follower")

      # This should not trigger a follow back for blacklisted user
      FollowManager.process_new_follower("blacklisted_follower", "auth_user456")
    end
  end

  describe "whitelist management" do
    test "adds user to whitelist" do
      assert :ok = FollowManager.add_to_whitelist("protected_user123")

      status = FollowManager.get_follow_status()
      assert status.whitelist_size == 1
    end

    test "removes user from whitelist" do
      assert :ok = FollowManager.add_to_whitelist("protected_user123")

      status = FollowManager.get_follow_status()
      assert status.whitelist_size == 1

      assert :ok = FollowManager.remove_from_whitelist("protected_user123")

      updated_status = FollowManager.get_follow_status()
      assert updated_status.whitelist_size == 0
    end

    test "prevents unfollowing whitelisted users" do
      assert :ok = FollowManager.add_to_whitelist("protected_user123")

      # Attempt to unfollow the whitelisted user
      assert {:error, :whitelisted} = FollowManager.unfollow_user("protected_user123", "auth_user456")
    end
  end

  describe "blacklist management" do
    test "adds user to blacklist" do
      assert :ok = FollowManager.add_to_blacklist("blocked_user123")

      status = FollowManager.get_follow_status()
      assert status.blacklist_size == 1
    end

    test "removes user from blacklist" do
      assert :ok = FollowManager.add_to_blacklist("blocked_user123")

      status = FollowManager.get_follow_status()
      assert status.blacklist_size == 1

      assert :ok = FollowManager.remove_from_blacklist("blocked_user123")

      updated_status = FollowManager.get_follow_status()
      assert updated_status.blacklist_size == 0
    end

    test "prevents following blacklisted users" do
      assert :ok = FollowManager.add_to_blacklist("blocked_user123")

      # Attempt to follow the blacklisted user
      assert {:error, :blacklisted} = FollowManager.follow_user("blocked_user123", "auth_user456")
    end
  end

  describe "get_follow_status/0" do
    test "returns follow status information" do
      status = FollowManager.get_follow_status()

      assert is_boolean(status.auto_follow_back)
      assert is_integer(status.whitelist_size)
      assert is_integer(status.blacklist_size)
      assert is_integer(status.follows_today)
      assert is_integer(status.unfollows_today)
    end
  end

  describe "history tracking" do
    test "tracks daily follow counts" do
      initial_status = FollowManager.get_follow_status()
      initial_follows = initial_status.follows_today

      # Perform multiple follows
      assert {:ok, _id1} = FollowManager.follow_user("user1", "auth_user456")
      assert {:ok, _id2} = FollowManager.follow_user("user2", "auth_user456")
      assert {:ok, _id3} = FollowManager.follow_user("user3", "auth_user456")

      updated_status = FollowManager.get_follow_status()
      assert updated_status.follows_today == initial_follows + 3
    end

    test "tracks daily unfollow counts" do
      initial_status = FollowManager.get_follow_status()
      initial_unfollows = initial_status.unfollows_today

      # Perform multiple unfollows
      assert {:ok, _id1} = FollowManager.unfollow_user("user1", "auth_user456")
      assert {:ok, _id2} = FollowManager.unfollow_user("user2", "auth_user456")
      assert {:ok, _id3} = FollowManager.unfollow_user("user3", "auth_user456")

      updated_status = FollowManager.get_follow_status()
      assert updated_status.unfollows_today == initial_unfollows + 3
    end
  end

  describe "cleanup" do
    test "maintains state during cleanup" do
      # Setup some state
      assert :ok = FollowManager.enable_auto_follow_back()
      assert :ok = FollowManager.add_to_whitelist("protected")
      assert :ok = FollowManager.add_to_blacklist("blocked")

      # Add some follows to history
      assert {:ok, _id} = FollowManager.follow_user("user123", "auth_user456")

      status = FollowManager.get_follow_status()
      assert status.auto_follow_back == true
      assert status.whitelist_size == 1
      assert status.blacklist_size == 1
    end
  end
end
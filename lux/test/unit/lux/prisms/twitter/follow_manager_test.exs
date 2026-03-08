defmodule Lux.Prisms.Twitter.FollowManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.FollowManager

  setup do
    name = :"follow_#{:rand.uniform(1_000_000)}"
    {:ok, pid} = FollowManager.start_link(name: name, daily_limit: 3)
    %{pid: pid}
  end

  test "queue follow", %{pid: pid} do
    {:ok, entry} = FollowManager.queue_follow(pid, "user1")
    assert entry.action == :follow
    {:ok, pending} = FollowManager.get_pending(pid)
    assert length(pending) == 1
  end

  test "queue unfollow", %{pid: pid} do
    {:ok, entry} = FollowManager.queue_unfollow(pid, "user1", :inactive)
    assert entry.action == :unfollow
  end

  test "mark follow done", %{pid: pid} do
    {:ok, _} = FollowManager.queue_follow(pid, "user1")
    :ok = FollowManager.mark_done(pid, "user1", :follow)
    {:ok, pending} = FollowManager.get_pending(pid)
    assert pending == []
    {:ok, s} = FollowManager.stats(pid)
    assert s.following == 1
    assert s.daily_count == 1
  end

  test "mark unfollow done", %{pid: pid} do
    {:ok, _} = FollowManager.queue_follow(pid, "user1")
    :ok = FollowManager.mark_done(pid, "user1", :follow)
    {:ok, _} = FollowManager.queue_unfollow(pid, "user1")
    :ok = FollowManager.mark_done(pid, "user1", :unfollow)
    {:ok, s} = FollowManager.stats(pid)
    assert s.following == 0
    assert s.unfollowed_total == 1
  end

  test "daily limit enforcement", %{pid: pid} do
    for i <- 1..3 do
      {:ok, _} = FollowManager.queue_follow(pid, "user#{i}")
      :ok = FollowManager.mark_done(pid, "user#{i}", :follow)
    end
    assert {:error, :daily_limit_reached} = FollowManager.queue_follow(pid, "user4")
  end

  test "stats", %{pid: pid} do
    {:ok, s} = FollowManager.stats(pid)
    assert s.following == 0
    assert s.daily_limit == 3
  end
end

defmodule Lux.Integrations.Telegram.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.RateLimiter

  setup do
    {:ok, pid} = RateLimiter.start_link(name: nil)
    %{pid: pid}
  end

  test "allows first request", %{pid: pid} do
    assert :ok = RateLimiter.check(pid, "chat1")
  end

  test "acquire records and returns ok", %{pid: pid} do
    assert :ok = RateLimiter.acquire(pid, "chat1")
  end

  test "blocks same chat within window", %{pid: pid} do
    :ok = RateLimiter.acquire(pid, "chat1")
    assert {:wait, _ms} = RateLimiter.check(pid, "chat1")
  end

  test "allows different chats", %{pid: pid} do
    :ok = RateLimiter.acquire(pid, "chat1")
    assert :ok = RateLimiter.check(pid, "chat2")
  end

  test "status returns counts", %{pid: pid} do
    RateLimiter.acquire(pid, "chat1")
    RateLimiter.acquire(pid, "chat2")

    status = RateLimiter.status(pid)
    assert status.global_used == 2
    assert status.global_limit == 30
    assert status.active_chats == 2
  end

  test "record via cast", %{pid: pid} do
    RateLimiter.record(pid, "chat1")
    Process.sleep(10)

    status = RateLimiter.status(pid)
    assert status.global_used >= 1
  end
end

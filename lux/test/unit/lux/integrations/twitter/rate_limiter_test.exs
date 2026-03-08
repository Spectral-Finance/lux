defmodule Lux.Integrations.Twitter.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.RateLimiter

  setup do
    {:ok, pid} = RateLimiter.start_link()
    %{pid: pid}
  end

  describe "check/2" do
    test "allows requests to unknown endpoints", %{pid: pid} do
      assert :ok = RateLimiter.check(pid, "/2/tweets")
    end

    test "allows requests when remaining is above threshold", %{pid: pid} do
      RateLimiter.update(pid, "/2/tweets", %{
        remaining: 100,
        limit: 300,
        reset_at: System.system_time(:second) + 900
      })

      assert :ok = RateLimiter.check(pid, "/2/tweets")
    end

    test "returns wait when remaining is below threshold", %{pid: pid} do
      reset_at = System.system_time(:second) + 60

      RateLimiter.update(pid, "/2/tweets", %{
        remaining: 3,
        limit: 300,
        reset_at: reset_at
      })

      # Give cast time to process
      :timer.sleep(20)

      assert {:wait, ms} = RateLimiter.check(pid, "/2/tweets")
      assert ms > 0
      assert ms <= 60_000
    end

    test "returns wait when remaining is zero", %{pid: pid} do
      reset_at = System.system_time(:second) + 30

      RateLimiter.update(pid, "/2/tweets", %{
        remaining: 0,
        limit: 300,
        reset_at: reset_at
      })

      :timer.sleep(20)

      assert {:wait, ms} = RateLimiter.check(pid, "/2/tweets")
      assert ms > 0
    end

    test "allows requests when reset time has passed", %{pid: pid} do
      RateLimiter.update(pid, "/2/tweets", %{
        remaining: 0,
        limit: 300,
        reset_at: System.system_time(:second) - 10
      })

      :timer.sleep(20)

      assert :ok = RateLimiter.check(pid, "/2/tweets")
    end
  end

  describe "record_rate_limited/3" do
    test "marks endpoint as rate limited", %{pid: pid} do
      reset_at = System.system_time(:second) + 120

      RateLimiter.record_rate_limited(pid, "/2/tweets/search/recent", reset_at)
      :timer.sleep(20)

      assert {:wait, ms} = RateLimiter.check(pid, "/2/tweets/search/recent")
      assert ms > 0
      assert ms <= 120_000
    end

    test "uses default window when no reset_at", %{pid: pid} do
      RateLimiter.record_rate_limited(pid, "/2/users/me", nil)
      :timer.sleep(20)

      assert {:wait, _ms} = RateLimiter.check(pid, "/2/users/me")
    end
  end

  describe "status/1" do
    test "returns all tracked endpoints", %{pid: pid} do
      RateLimiter.update(pid, "/2/tweets", %{remaining: 100, limit: 300, reset_at: 0})
      RateLimiter.update(pid, "/2/users", %{remaining: 50, limit: 900, reset_at: 0})
      :timer.sleep(20)

      status = RateLimiter.status(pid)
      assert Map.has_key?(status, "/2/tweets")
      assert Map.has_key?(status, "/2/users")
    end
  end

  describe "reset/2" do
    test "removes endpoint tracking", %{pid: pid} do
      RateLimiter.record_rate_limited(pid, "/2/tweets", System.system_time(:second) + 60)
      :timer.sleep(20)
      assert {:wait, _} = RateLimiter.check(pid, "/2/tweets")

      RateLimiter.reset(pid, "/2/tweets")
      :timer.sleep(20)
      assert :ok = RateLimiter.check(pid, "/2/tweets")
    end
  end

  describe "independent endpoint tracking" do
    test "different endpoints tracked separately", %{pid: pid} do
      RateLimiter.record_rate_limited(pid, "/2/tweets", System.system_time(:second) + 60)
      :timer.sleep(20)

      assert {:wait, _} = RateLimiter.check(pid, "/2/tweets")
      assert :ok = RateLimiter.check(pid, "/2/users")
    end
  end
end

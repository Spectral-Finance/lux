defmodule Lux.Integrations.Binance.RateLimiterTest do
  use UnitAPICase, async: false

  alias Lux.Integrations.Binance.RateLimiter

  setup do
    {:ok, pid} =
      GenServer.start_link(RateLimiter,
        [
          name: :test_binance_rate_limiter,
          ets_table: :test_binance_rate_limiter,
          spot_rpm: 100,
          futures_rpm: 100,
          order_rps: 5,
          refill_interval_ms: 100
        ],
        []
      )

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "acquire/3" do
    test "acquires a spot token successfully", %{pid: pid} do
      assert RateLimiter.acquire(pid, :spot) == :ok
    end

    test "acquires a futures token successfully", %{pid: pid} do
      assert RateLimiter.acquire(pid, :futures) == :ok
    end

    test "acquires an orders token successfully", %{pid: pid} do
      assert RateLimiter.acquire(pid, :orders) == :ok
    end
  end

  describe "get_bucket_status/1" do
    test "returns all bucket statuses", %{pid: pid} do
      status = RateLimiter.get_bucket_status(pid)

      assert is_map(status)
      assert Map.has_key?(status, :spot)
      assert Map.has_key?(status, :futures)
      assert Map.has_key?(status, :orders)
    end
  end

  describe "update_config/2" do
    test "updates rate limit config", %{pid: pid} do
      RateLimiter.update_config(pid, %{spot_rpm: 50})
      status = RateLimiter.get_bucket_status(pid)

      assert status.spot <= 50
    end
  end
end

defmodule Lux.Binance.RateLimiterTest do
  use ExUnit.Case, async: false
  alias Lux.Binance.RateLimiter

  setup do
    RateLimiter.reset()
    :ok
  end

  describe "record_response/3 & check_rate_limit/1" do
    test "initially allows requests without backoff" do
      assert RateLimiter.check_rate_limit(:spot) == :ok
      assert RateLimiter.check_rate_limit(:futures) == :ok
    end

    test "records used weight headers for spot and futures" do
      headers_spot = [{"x-mbx-used-weight-1m", "45"}]
      RateLimiter.record_response(headers_spot, 200, :spot)
      assert RateLimiter.get_used_weight(:spot) == 45

      headers_futures = [{"x-fapi-used-weight-1m", "120"}]
      RateLimiter.record_response(headers_futures, 200, :futures)
      assert RateLimiter.get_used_weight(:futures) == 120
    end

    test "triggers backoff when receiving HTTP 429 with Retry-After header" do
      headers = [{"retry-after", "10"}, {"x-mbx-used-weight-1m", "1200"}]
      RateLimiter.record_response(headers, 429, :spot)

      assert {:error, {:rate_limited, wait_ms}} = RateLimiter.check_rate_limit(:spot)
      assert wait_ms > 0 and wait_ms <= 10_000

      # Futures should remain unaffected
      assert RateLimiter.check_rate_limit(:futures) == :ok
    end

    test "triggers backoff when receiving HTTP 418" do
      headers = [{"retry-after", "5"}]
      RateLimiter.record_response(headers, 418, :futures)

      assert {:error, {:rate_limited, wait_ms}} = RateLimiter.check_rate_limit(:futures)
      assert wait_ms > 0 and wait_ms <= 5_000
    end
  end

  describe "RateLimiter durability" do
    test "maintains ETS state even if the caller process dies (owner-restart resilience)" do
      # Spawn a temporary process to act as the "caller"
      task = Task.async(fn ->
        headers = [{"retry-after", "20"}, {"x-mbx-used-weight-1m", "2000"}]
        RateLimiter.record_rate_limit(headers, 429, :spot)
        RateLimiter.check_rate_limit(:spot)
      end)
      
      # Wait for the caller to finish and die
      assert {:error, {:rate_limited, wait_ms}} = Task.await(task)
      assert wait_ms > 0
      
      # Since the RateLimiter GenServer (and not the caller) owns the ETS table,
      # the backoff should still be active for the main test process.
      assert {:error, {:rate_limited, new_wait}} = RateLimiter.check_rate_limit(:spot)
      assert new_wait > 0
    end
  end
end

defmodule Lux.Integrations.Twitter.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.RateLimiter

  describe "rate limit state tracking" do
    test "checks quota and updates from response headers" do
      state = RateLimiter.init_state()
      assert RateLimiter.check_quota(state, "/tweets") == :ok

      headers = [
        {"x-rate-limit-limit", "50"},
        {"x-rate-limit-remaining", "0"},
        {"x-rate-limit-reset", "2000000000"}
      ]

      updated = RateLimiter.update_from_headers(state, "/tweets", headers, 1_700_000_000)

      # Remaining is 0 and reset is in the future
      assert {:wait_until, 2_000_000_000} =
               RateLimiter.check_quota(updated, "/tweets", 1_700_000_000)

      # Once current time exceeds reset, quota passes
      assert :ok = RateLimiter.check_quota(updated, "/tweets", 2_000_000_001)
    end
  end

  describe "calculate_backoff/3" do
    test "calculates backoff using reset timestamp when available" do
      reset_at = 1_700_000_050
      now = 1_700_000_000
      delay = RateLimiter.calculate_backoff(1, reset_at, now)
      # 50s + 1s safety jitter = 51s = 51000ms
      assert delay == 51_000
    end

    test "calculates exponential backoff with jitter when reset not provided" do
      delay1 = RateLimiter.calculate_backoff(1, nil)
      assert delay1 >= 2000 and delay1 <= 2600

      delay2 = RateLimiter.calculate_backoff(2, nil)
      assert delay2 >= 4000 and delay2 <= 4600
    end
  end
end

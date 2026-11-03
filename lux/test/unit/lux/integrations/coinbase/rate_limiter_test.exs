defmodule Lux.Integrations.Coinbase.RateLimiterTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.RateLimiter

  describe "can_request?/2" do
    test "allows requests under threshold" do
      state = RateLimiter.init()
      assert {:ok, updated} = RateLimiter.can_request?(state, false)
      assert updated.req_count == 1
    end

    test "allows order requests under higher order threshold" do
      state = %{RateLimiter.init() | req_count: 50}
      assert {:ok, updated} = RateLimiter.can_request?(state, true)
      assert updated.req_count == 51
    end

    test "throttles when general request rate limit is hit" do
      state = %{RateLimiter.init() | req_count: 30}
      assert {:error, :rate_limited, wait_sec} = RateLimiter.can_request?(state, false)
      assert wait_sec == 1
    end
  end

  describe "handle_rate_limit/2" do
    test "sets backoff penalty" do
      state = RateLimiter.init()
      penalized = RateLimiter.handle_rate_limit(state, 5)

      assert penalized.backoff_until > :os.system_time(:second)
      assert {:error, :rate_limited, _} = RateLimiter.can_request?(penalized)
    end
  end
end

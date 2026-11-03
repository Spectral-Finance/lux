defmodule Lux.Integrations.Binance.RateLimiterTest do
  use UnitCase, async: true

  alias Lux.Integrations.Binance.RateLimiter

  describe "can_request?/3" do
    test "allows requests within weight budget" do
      state = RateLimiter.init()
      assert {:ok, updated} = RateLimiter.can_request?(state, 5, false)
      assert updated.used_ip_weight == 5
      assert updated.orders_in_window == 0
    end

    test "tracks order count increments" do
      state = RateLimiter.init()
      assert {:ok, updated} = RateLimiter.can_request?(state, 1, true)
      assert updated.orders_in_window == 1
    end

    test "rejects when ip weight limit is exceeded" do
      state = %{RateLimiter.init() | used_ip_weight: 1200}
      assert {:error, :rate_limited, wait_sec} = RateLimiter.can_request?(state, 1, false)
      assert wait_sec > 0
    end
  end

  describe "handle_rate_limit_response/3" do
    test "applies backoff penalty on 429 response" do
      state = RateLimiter.init()
      penalized = RateLimiter.handle_rate_limit_response(state, 429, 60)
      assert penalized.backoff_until > :os.system_time(:second)

      assert {:error, :rate_limited, _} = RateLimiter.can_request?(penalized, 1)
    end

    test "applies minimum 300s penalty on 418 ip ban" do
      state = RateLimiter.init()
      penalized = RateLimiter.handle_rate_limit_response(state, 418, 10)
      diff = penalized.backoff_until - :os.system_time(:second)
      assert diff >= 295
    end
  end
end

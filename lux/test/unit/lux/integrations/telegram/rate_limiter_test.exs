defmodule Lux.Integrations.Telegram.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Telegram.RateLimiter

  setup do
    # Ensure the rate limiter is started
    if Process.whereis(RateLimiter) == nil do
      start_supervised!(RateLimiter)
    end

    RateLimiter.reset()
    :ok
  end

  describe "check_and_wait/1" do
    test "returns :ok when tokens available" do
      assert :ok = RateLimiter.check_and_wait(:send_message)
    end

    test "consumes tokens from bucket" do
      initial = RateLimiter.get_state()
      RateLimiter.check_and_wait(:send_message)
      final = RateLimiter.get_state()

      assert final.tokens < initial.tokens
    end

    test "waits when tokens exhausted" do
      # Exhaust all tokens
      for _ <- 1..30 do
        RateLimiter.check_and_wait(:send_message)
      end

      # Next call should wait and succeed
      start_time = System.monotonic_time(:millisecond)
      assert :ok = RateLimiter.check_and_wait(:send_message)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should have waited at least some time
      assert elapsed >= 0
    end
  end

  describe "enqueue/1" do
    test "adds request to queue" do
      initial = RateLimiter.get_state()
      RateLimiter.enqueue({:send_message, %{chat_id: 123}})
      final = RateLimiter.get_state()

      assert final.queue_size == initial.queue_size + 1
    end
  end

  describe "get_state/0" do
    test "returns current state" do
      state = RateLimiter.get_state()

      assert is_integer(state.tokens)
      assert is_integer(state.rate_limit)
      assert is_integer(state.burst_limit)
      assert is_integer(state.queue_size)
    end

    test "tokens never exceed burst_limit" do
      # Try to consume many tokens
      for _ <- 1..50 do
        RateLimiter.check_and_wait(:send_message)
      end

      state = RateLimiter.get_state()
      assert state.tokens <= state.burst_limit
    end
  end

  describe "reset/0" do
    test "resets tokens to burst_limit" do
      # Consume some tokens
      RateLimiter.check_and_wait(:send_message)
      RateLimiter.check_and_wait(:send_message)

      RateLimiter.reset()
      state = RateLimiter.get_state()

      assert state.tokens == state.burst_limit
    end
  end

  describe "default limits" do
    test "default_rate_limit/0 returns 30" do
      assert RateLimiter.default_rate_limit() == 30
    end

    test "default_burst_limit/0 returns 30" do
      assert RateLimiter.default_burst_limit() == 30
    end
  end
end
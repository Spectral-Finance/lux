defmodule Lux.Integrations.Telegram.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.RateLimiter

  describe "rate limit checks" do
    test "allows initial message under private chat limit" do
      state = RateLimiter.init_state()
      assert {:ok, _updated} = RateLimiter.check_rate_limit(state, "12345", :private, 1_000)
    end

    test "throttles rapid subsequent messages to same private chat within 1s" do
      state = RateLimiter.init_state()
      {:ok, state1} = RateLimiter.check_rate_limit(state, "12345", :private, 1_000)

      # Attempt immediate second message 100ms later -> throttled
      assert {:rate_limited, wait_ms, reason} =
               RateLimiter.check_rate_limit(state1, "12345", :private, 1_100)

      assert wait_ms >= 50
      assert String.contains?(reason, "Private chat limit")

      # After 1000ms elapses, message is allowed
      assert {:ok, _state2} = RateLimiter.check_rate_limit(state1, "12345", :private, 2_001)
    end

    test "throttles when global 30 msgs/sec limit is exceeded" do
      state = RateLimiter.init_state()
      now = 10_000

      # Fill 30 different chats within same second
      state_filled =
        Enum.reduce(1..30, state, fn i, acc ->
          {:ok, next_state} = RateLimiter.check_rate_limit(acc, "chat_#{i}", :private, now)
          next_state
        end)

      # 31st message to fresh chat 31 within same second should hit global throttle
      assert {:rate_limited, _wait_ms, reason} =
               RateLimiter.check_rate_limit(state_filled, "chat_31", :private, now + 100)

      assert String.contains?(reason, "Global limit exceeded")
    end

    test "enforces group chat limit of 20 messages per minute" do
      state = RateLimiter.init_state()
      now = 50_000

      state_filled =
        Enum.reduce(1..20, state, fn i, acc ->
          {:ok, next_state} = RateLimiter.check_rate_limit(acc, "group_999", :group, now + (i * 100))
          next_state
        end)

      assert {:rate_limited, _wait, reason} =
               RateLimiter.check_rate_limit(state_filled, "group_999", :group, now + 3000)

      assert String.contains?(reason, "Group chat limit")
    end
  end

  describe "record_retry_after/3 and calculate_backoff/1" do
    test "enforces retry_after from Telegram 429 response" do
      state = RateLimiter.init_state()
      resp = %{"parameters" => %{"retry_after" => 5}}

      updated = RateLimiter.record_retry_after(state, "chat_429", resp)

      # Chat is penalized
      assert {:rate_limited, wait_ms, reason} =
               RateLimiter.check_rate_limit(updated, "chat_429", :private, :os.system_time(:millisecond))

      assert wait_ms > 0
      assert String.contains?(reason, "retry_after")
    end

    test "calculates backoff with jitter" do
      backoff = RateLimiter.calculate_backoff(2)
      assert backoff >= 2000 and backoff <= 2300
    end
  end
end

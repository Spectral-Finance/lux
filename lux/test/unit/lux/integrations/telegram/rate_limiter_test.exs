defmodule Lux.Integrations.Telegram.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Telegram.RateLimiter

  @moduletag :unit

  setup do
    # Clean up any existing ETS table and start fresh
    if :ets.whereis(:telegram_rate_limiter) != :undefined do
      :ets.delete(:telegram_rate_limiter)
    end

    start_supervised!({RateLimiter, name: RateLimiter})
    :ok
  end

  describe "check_rate/0" do
    test "allows requests when under global limit" do
      assert :ok = RateLimiter.check_rate()
    end

    test "rate limits when global limit is exceeded" do
      # Track 30 requests (the global limit)
      for _ <- 1..30 do
        RateLimiter.track_request()
      end

      assert {:error, :rate_limited, retry_after} = RateLimiter.check_rate()
      assert is_integer(retry_after)
      assert retry_after > 0
    end
  end

  describe "check_rate/1" do
    test "allows requests when under per-chat limit" do
      chat_id = 123_456_789
      assert :ok = RateLimiter.check_rate(chat_id)
    end

    test "rate limits private chat after 1 message per second" do
      chat_id = 123_456_789

      # Track 1 request for this chat
      RateLimiter.track_request(chat_id)

      assert {:error, :rate_limited, retry_after} = RateLimiter.check_rate(chat_id)
      assert is_integer(retry_after)
      assert retry_after > 0
    end

    test "allows more messages for group chats (negative IDs)" do
      group_id = -100_123_456

      # Track 1 request - should still be under group limit of 3
      RateLimiter.track_request(group_id)

      assert :ok = RateLimiter.check_rate(group_id)

      # Track 2 more
      RateLimiter.track_request(group_id)
      RateLimiter.track_request(group_id)

      assert {:error, :rate_limited, _retry_after} = RateLimiter.check_rate(group_id)
    end

    test "global limit is checked alongside per-chat limit" do
      chat_id = 123_456_789

      # Fill up global limit
      for _ <- 1..30 do
        RateLimiter.track_request()
      end

      assert {:error, :rate_limited, _retry_after} = RateLimiter.check_rate(chat_id)
    end
  end

  describe "track_request/0" do
    test "tracks global requests" do
      assert :ok = RateLimiter.track_request()
    end
  end

  describe "track_request/1" do
    test "tracks per-chat requests" do
      assert :ok = RateLimiter.track_request(123_456_789)
    end

    test "tracks both global and per-chat" do
      chat_id = 123_456_789

      # After tracking a per-chat request, both global and chat entries should exist
      RateLimiter.track_request(chat_id)

      # Global should have 1 tracked request
      # Chat should have 1 tracked request
      # Second per-chat request should be rate limited (limit is 1/sec for private)
      assert {:error, :rate_limited, _} = RateLimiter.check_rate(chat_id)
    end
  end
end

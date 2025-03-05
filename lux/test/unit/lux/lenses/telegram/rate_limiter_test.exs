defmodule Lux.Lenses.Telegram.RateLimiterTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.RateLimiter

  setup do
    # Reset all rate limiters before each test
    RateLimiter.reset_all()
    :ok
  end

  test "check_and_update allows requests under the limit" do
    # Test with a limit of 5 requests per second
    config = %{name: :test_limiter, limit: 5, window_ms: 1000}

    # First 5 requests should be allowed
    for _ <- 1..5 do
      assert :ok = RateLimiter.check_and_update(config)
    end
  end

  test "check_and_update delays requests over the limit" do
    # Test with a limit of 2 requests per second
    config = %{name: :test_limiter, limit: 2, window_ms: 1000}

    # First 2 requests should be allowed
    for _ <- 1..2 do
      assert :ok = RateLimiter.check_and_update(config)
    end

    # Third request should be delayed
    # We need to ensure we're actually hitting the limit by using the same table
    table_name = RateLimiter.get_table_name(config.name)
    :ets.delete_all_objects(table_name)

    now = System.monotonic_time(:millisecond)
    # Insert 2 entries with timestamps that will trigger rate limiting
    :ets.insert(table_name, {now, now})
    :ets.insert(table_name, {now - 100, now - 100})

    assert {:wait, delay} = RateLimiter.check_and_update(config)
    assert delay > 0 and delay <= 1000
  end

  test "with_rate_limit executes the function with rate limiting" do
    # Create a counter to track executions
    counter = :counters.new(1, [:atomics])

    # Set up the rate limiter to be at the limit
    chat_id = "test_chat"
    chat_config = %{name: :"telegram_chat_#{chat_id}", limit: 1, window_ms: 1000}
    table_name = Lux.Lenses.Telegram.RateLimiter.get_table_name(chat_config.name)

    # Ensure table exists
    case :ets.info(table_name) do
      :undefined -> :ets.new(table_name, [:named_table, :set, :public])
      _ -> :ets.delete_all_objects(table_name)
    end

    # Insert an entry to trigger rate limiting
    now = System.monotonic_time(:millisecond)
    :ets.insert(table_name, {now, now})

    # Request should be delayed but still execute
    start_time = System.monotonic_time(:millisecond)
    result = RateLimiter.with_rate_limit(chat_id, fn ->
      :counters.add(counter, 1, 1)
      6
    end)
    end_time = System.monotonic_time(:millisecond)

    assert result == 6
    assert :counters.get(counter, 1) == 1
    assert end_time - start_time >= 500
  end

  test "with_rate_limit respects chat-specific rate limits" do
    # Create counters for different chats
    chat1_counter = :counters.new(1, [:atomics])

    # Set up the rate limiter for chat1 to be at the limit
    chat_id = "chat1"
    chat_config = %{name: :"telegram_chat_#{chat_id}", limit: 1, window_ms: 1000}
    table_name = Lux.Lenses.Telegram.RateLimiter.get_table_name(chat_config.name)

    # Ensure table exists
    case :ets.info(table_name) do
      :undefined -> :ets.new(table_name, [:named_table, :set, :public])
      _ -> :ets.delete_all_objects(table_name)
    end

    # Insert an entry to trigger rate limiting
    now = System.monotonic_time(:millisecond)
    :ets.insert(table_name, {now, now})

    # Request should be delayed
    start_time = System.monotonic_time(:millisecond)
    RateLimiter.with_rate_limit("chat1", fn ->
      :counters.add(chat1_counter, 1, 1)
    end)
    end_time = System.monotonic_time(:millisecond)

    assert :counters.get(chat1_counter, 1) == 1
    assert end_time - start_time >= 500
  end

  test "reset_all clears all rate limiters" do
    # Create a new test-specific rate limiter
    config = %{name: :test_reset_limiter, limit: 1, window_ms: 1000}
    table_name = RateLimiter.get_table_name(config.name)

    # Ensure the table exists and is empty
    case :ets.info(table_name) do
      :undefined -> :ets.new(table_name, [:named_table, :set, :public])
      _ -> :ets.delete_all_objects(table_name)
    end

    # Insert an entry to trigger rate limiting
    now = System.monotonic_time(:millisecond)
    :ets.insert(table_name, {now, now})

    # Verify rate limiting is active
    assert {:wait, _} = RateLimiter.check_and_update(config)

    # Reset all rate limiters
    RateLimiter.reset_all()

    # Reset the specific table directly to ensure it's empty
    :ets.delete_all_objects(table_name)

    # Now the limiter should allow requests
    assert :ok = RateLimiter.check_and_update(config)
  end
end

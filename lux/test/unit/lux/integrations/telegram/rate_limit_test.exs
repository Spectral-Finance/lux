defmodule Lux.Integrations.Telegram.RateLimitTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.RateLimit

  describe "retryable_status?/1" do
    test "matches Telegram rate limits and transient failures" do
      assert RateLimit.retryable_status?(429)
      assert RateLimit.retryable_status?(500)
      assert RateLimit.retryable_status?(503)
      refute RateLimit.retryable_status?(400)
      refute RateLimit.retryable_status?(401)
    end
  end

  describe "retry_delay_ms/5" do
    test "prefers Telegram retry_after from response body" do
      body = %{"parameters" => %{"retry_after" => 3}}

      assert RateLimit.retry_delay_ms(429, body, [], 0, base_delay_ms: 100) == 3000
    end

    test "uses Retry-After response header when body does not include retry_after" do
      headers = [{"retry-after", "4"}]

      assert RateLimit.retry_delay_ms(429, %{}, headers, 0, base_delay_ms: 100) == 4000
    end

    test "falls back to exponential backoff for transient errors" do
      assert RateLimit.retry_delay_ms(500, %{}, [], 0, base_delay_ms: 250) == 250
      assert RateLimit.retry_delay_ms(500, %{}, [], 2, base_delay_ms: 250) == 1000
    end
  end
end

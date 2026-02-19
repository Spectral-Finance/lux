defmodule Lux.Integrations.Binance.RateLimiterTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias Lux.Integrations.Binance.RateLimiter

  setup do
    # Stop any existing rate limiter
    case Process.whereis(RateLimiter) do
      nil -> :ok
      pid ->
        GenServer.stop(pid, :normal)
        Process.sleep(10)
    end

    {:ok, _pid} = RateLimiter.start_link()
    RateLimiter.reset()
    :ok
  end

  describe "check_rate/3" do
    test "allows request within limits" do
      assert :ok = RateLimiter.check_rate(:spot, :request, 1)
    end

    test "allows request with custom weight" do
      assert :ok = RateLimiter.check_rate(:spot, :request, 10)
    end

    test "rejects request when limit exceeded" do
      # Record requests up to the limit
      for _i <- 1..1_200 do
        RateLimiter.record_request(:spot, :request, 1)
      end

      assert {:error, :rate_limited} = RateLimiter.check_rate(:spot, :request, 1)
    end

    test "tracks spot and futures limits independently" do
      for _i <- 1..1_200 do
        RateLimiter.record_request(:spot, :request, 1)
      end

      # Spot should be limited
      assert {:error, :rate_limited} = RateLimiter.check_rate(:spot, :request, 1)

      # Futures should still be fine
      assert :ok = RateLimiter.check_rate(:futures, :request, 1)
    end

    test "tracks order limits separately from request limits" do
      for _i <- 1..100 do
        RateLimiter.record_request(:spot, :order, 1)
      end

      # Order limit exceeded
      assert {:error, :rate_limited} = RateLimiter.check_rate(:spot, :order, 1)

      # Request limit still fine
      assert :ok = RateLimiter.check_rate(:spot, :request, 1)
    end
  end

  describe "record_request/3" do
    test "records a request with weight" do
      assert :ok = RateLimiter.record_request(:spot, :request, 5)
      assert RateLimiter.current_weight(:spot, :request) == 5
    end

    test "accumulates weights" do
      RateLimiter.record_request(:spot, :request, 3)
      RateLimiter.record_request(:spot, :request, 7)
      assert RateLimiter.current_weight(:spot, :request) == 10
    end
  end

  describe "current_weight/2" do
    test "returns 0 for no requests" do
      assert RateLimiter.current_weight(:spot, :request) == 0
    end

    test "returns accumulated weight" do
      RateLimiter.record_request(:futures, :request, 10)
      RateLimiter.record_request(:futures, :request, 20)
      assert RateLimiter.current_weight(:futures, :request) == 30
    end
  end

  describe "reset/0" do
    test "clears all rate limit counters" do
      RateLimiter.record_request(:spot, :request, 100)
      RateLimiter.record_request(:futures, :request, 200)

      RateLimiter.reset()

      assert RateLimiter.current_weight(:spot, :request) == 0
      assert RateLimiter.current_weight(:futures, :request) == 0
    end
  end
end

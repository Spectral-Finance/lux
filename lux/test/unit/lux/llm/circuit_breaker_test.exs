defmodule Lux.LLM.CircuitBreakerTest do
  use UnitAPICase, async: false

  alias Lux.LLM.CircuitBreaker

  setup do
    Application.put_env(:lux, CircuitBreaker, cooldown_ms: 30)
    start_supervised!({CircuitBreaker, failure_threshold: 2, cooldown_ms: 30})
    on_exit(fn -> Application.delete_env(:lux, CircuitBreaker) end)
    :ok
  end

  describe "allow?/1" do
    test "allows unknown providers" do
      assert CircuitBreaker.allow?(Unknown.Provider)
      assert CircuitBreaker.status(Unknown.Provider) == :closed
    end

    test "opens after the failure threshold and closes on success" do
      provider = SomeProvider

      CircuitBreaker.record_failure(provider)
      assert CircuitBreaker.status(provider) == :closed
      assert CircuitBreaker.allow?(provider)

      CircuitBreaker.record_failure(provider)
      # the second failure crosses the threshold
      refute CircuitBreaker.allow?(provider)
      assert CircuitBreaker.status(provider) == :open

      CircuitBreaker.record_success(provider)
      assert CircuitBreaker.status(provider) == :closed
      assert CircuitBreaker.allow?(provider)
    end

    test "moves to half_open after the cooldown" do
      provider = CoolProvider

      CircuitBreaker.record_failure(provider)
      CircuitBreaker.record_failure(provider)
      assert CircuitBreaker.status(provider) == :open

      Process.sleep(60)
      assert CircuitBreaker.allow?(provider)
      Process.sleep(10)
      assert CircuitBreaker.status(provider) == :half_open

      # a failure while half_open re-opens the breaker
      CircuitBreaker.record_failure(provider)
      Process.sleep(10)
      assert CircuitBreaker.status(provider) == :open
    end

    test "reset/1 forgets the provider" do
      provider = ResetProvider

      CircuitBreaker.record_failure(provider)
      CircuitBreaker.record_failure(provider)
      assert CircuitBreaker.status(provider) == :open

      :ok = CircuitBreaker.reset(provider)
      assert CircuitBreaker.status(provider) == :closed
    end
  end
end

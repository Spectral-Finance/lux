defmodule Lux.LLM.CircuitBreakerTest do
  use ExUnit.Case, async: false

  alias Lux.LLM.CircuitBreaker

  setup do
    {:ok, pid} =
      CircuitBreaker.start_link(
        name: :test_cb,
        failure_threshold: 3,
        reset_timeout: 50
      )

    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)
    %{cb: :test_cb}
  end

  describe "allow_request?/2" do
    test "allows requests when circuit is closed", %{cb: cb} do
      assert CircuitBreaker.allow_request?(:openai, cb) == true
    end

    test "blocks requests when circuit is open", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      assert CircuitBreaker.allow_request?(:openai, cb) == false
    end
  end

  describe "state transitions" do
    test "closed -> open after threshold failures", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      assert {:ok, :open} = CircuitBreaker.get_state(:openai, cb)
    end

    test "open -> half_open after reset_timeout elapses", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      assert {:ok, :open} = CircuitBreaker.get_state(:openai, cb)
      Process.sleep(70)
      CircuitBreaker.allow_request?(:openai, cb)
      assert {:ok, :half_open} = CircuitBreaker.get_state(:openai, cb)
    end

    test "half_open -> closed after successful probe", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      Process.sleep(70)
      CircuitBreaker.allow_request?(:openai, cb)
      CircuitBreaker.record_success(:openai, cb)
      assert {:ok, :closed} = CircuitBreaker.get_state(:openai, cb)
    end

    test "half_open -> open after failed probe", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      Process.sleep(70)
      CircuitBreaker.allow_request?(:openai, cb)
      CircuitBreaker.record_failure(:openai, cb)
      assert {:ok, :open} = CircuitBreaker.get_state(:openai, cb)
    end
  end

  describe "reset/2" do
    test "manually resets open circuit to closed", %{cb: cb} do
      Enum.each(1..3, fn _ -> CircuitBreaker.record_failure(:openai, cb) end)
      assert {:ok, :open} = CircuitBreaker.get_state(:openai, cb)
      CircuitBreaker.reset(:openai, cb)
      Process.sleep(20)
      assert {:ok, :closed} = CircuitBreaker.get_state(:openai, cb)
    end
  end

  describe "get_all_info/1" do
    test "tracks multiple providers independently", %{cb: cb} do
      CircuitBreaker.record_failure(:openai, cb)
      CircuitBreaker.record_failure(:anthropic, cb)
      {:ok, all} = CircuitBreaker.get_all_info(cb)
      assert Map.has_key?(all, :openai)
      assert Map.has_key?(all, :anthropic)
    end
  end
end

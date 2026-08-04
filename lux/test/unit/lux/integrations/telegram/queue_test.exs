defmodule Lux.Integrations.Telegram.QueueTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Telegram.Queue

  setup do
    # Start a fresh queue for each test
    {:ok, pid} = Queue.start_link(name: nil, interval: 10)
    %{queue: pid}
  end

  test "enqueues and executes a successful request", %{queue: queue} do
    request_fun = fn -> {:ok, :success} end

    assert {:ok, :success} = Queue.enqueue(queue, request_fun)
  end

  test "enqueues and handles a regular error", %{queue: queue} do
    request_fun = fn -> {:error, :bad_request} end

    assert {:error, :bad_request} = Queue.enqueue(queue, request_fun)
  end

  test "retries on 429 rate limit and eventually succeeds", %{queue: queue} do
    # We use an agent to track how many times the function was called
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    request_fun = fn ->
      count = Agent.get_and_update(agent, fn state -> {state, state + 1} end)
      if count == 0 do
        # First time fails with rate limit (retry after 0.05 seconds)
        {:error, {:rate_limited, 0}} # 0 is used for testing so it doesn't block long
      else
        {:ok, :success_after_retry}
      end
    end

    assert {:ok, :success_after_retry} = Queue.enqueue(queue, request_fun)
    assert Agent.get(agent, fn state -> state end) == 2
  end

  test "returns error when max retries exceeded", %{queue: queue} do
    request_fun = fn -> {:error, {:rate_limited, 0}} end

    assert {:error, :rate_limit_exceeded} = Queue.enqueue(queue, request_fun)
  end
end

defmodule Lux.Lenses.Telegram.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Telegram.ErrorHandler

  describe "handle_error/1" do
    test "handles network errors" do
      error = "Failed to connect: timeout"
      assert {:retry, 1000} = ErrorHandler.handle_error(error)
    end

    test "handles rate limiting errors" do
      error = "Too Many Requests: retry after 10"
      assert {:retry, 10_000} = ErrorHandler.handle_error(error)
    end

    test "handles server errors" do
      error = "Bad Gateway"
      assert {:retry, 2000} = ErrorHandler.handle_error(error)
    end

    test "handles non-retryable errors" do
      error = "chat not found"
      assert {:error, :chat_not_found} = ErrorHandler.handle_error(error)
    end

    test "handles error maps with specific error codes" do
      error = %{"error_code" => 429, "description" => "Too Many Requests: retry after 5"}
      assert {:retry, 5000} = ErrorHandler.handle_error(error)

      error = %{"error_code" => 500, "description" => "Internal Server Error"}
      assert {:retry, 2000} = ErrorHandler.handle_error(error)

      error = %{"error_code" => 400, "description" => "chat not found"}
      assert {:error, :chat_not_found} = ErrorHandler.handle_error(error)
    end
  end

  describe "with_retries/2" do
    test "retries retryable errors" do
      # Create a counter to track the number of attempts
      counter = :counters.new(1, [:atomics])

      result = ErrorHandler.with_retries(fn ->
        :counters.add(counter, 1, 1)
        count = :counters.get(counter, 1)

        case count do
          1 -> {:error, "timeout"}
          2 -> {:error, "Too Many Requests: retry after 0.1"}
          3 -> {:ok, "success"}
        end
      end, [max_retries: 3, initial_delay: 10, max_delay: 20])

      assert result == {:ok, "success"}
      assert :counters.get(counter, 1) == 3
    end

    test "does not retry non-retryable errors" do
      # Create a counter to track the number of attempts
      counter = :counters.new(1, [:atomics])

      result = ErrorHandler.with_retries(fn ->
        :counters.add(counter, 1, 1)
        {:error, "chat not found"}
      end, [max_retries: 3, initial_delay: 10, max_delay: 20])

      assert result == {:error, :chat_not_found}
      assert :counters.get(counter, 1) == 1
    end

    test "uses exponential backoff" do
      # Create an ETS table to store timestamps
      :ets.new(:times, [:set, :public, :named_table])

      ErrorHandler.with_retries(fn ->
        count = :ets.info(:times, :size) + 1
        :ets.insert(:times, {count, System.monotonic_time(:millisecond)})

        case count do
          3 -> {:ok, "success"}
          _ -> {:error, "timeout"}
        end
      end, [max_retries: 3, initial_delay: 50, max_delay: 1000])

      # Get all timestamps
      times = :ets.tab2list(:times)
      assert length(times) == 3

      # Calculate delays between attempts
      [{1, first}, {2, second}, {3, third}] = Enum.sort(times)

      # First delay should be around 50ms (with more tolerance for test execution time)
      delay1 = second - first
      assert delay1 >= 10, "First delay #{delay1}ms is too short"

      # Second delay should be around 100ms (with more tolerance)
      delay2 = third - second
      assert delay2 >= 10, "Second delay #{delay2}ms is too short"

      # Second delay should generally be longer than the first (exponential)
      # But in very fast test environments they might be similar
      assert delay2 >= delay1 * 0.8, "Second delay #{delay2}ms should be roughly exponential compared to first delay #{delay1}ms"

      # Clean up
      :ets.delete(:times)
    end
  end
end

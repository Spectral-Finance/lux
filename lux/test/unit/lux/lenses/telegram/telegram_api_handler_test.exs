defmodule Lux.Lenses.Telegram.TelegramAPIHandlerTest do
  use UnitAPICase, async: false

  alias Lux.Lenses.Telegram.TelegramAPIHandler
  require Logger

  setup do
    # Save the current logger level
    original_level = Logger.level()

    # Set logger to only show critical errors during tests
    Logger.configure(level: :critical)

    # Reset all rate limiters before each test
    TelegramAPIHandler.reset_all()

    on_exit(fn ->
      # Restore the original logger level after the test
      Logger.configure(level: original_level)
    end)

    :ok
  end

  describe "with_rate_limit/3" do
    test "applies rate limiting based on method" do
      # Create a test function that counts calls
      Process.put(:call_count, 0)
      test_fun = fn ->
        count = Process.get(:call_count, 0)
        Process.put(:call_count, count + 1)
        {:ok, count}
      end

      # Call the function multiple times in quick succession
      params = %{chat_id: 123456789}
      method = "sendMessage"

      # First call should go through immediately
      assert {:ok, 0} = TelegramAPIHandler.with_rate_limit(params, method, test_fun)

      # Second call should also go through immediately
      assert {:ok, 1} = TelegramAPIHandler.with_rate_limit(params, method, test_fun)

      # For the third call, we'll manually set the rate limit to be exceeded
      # by making many calls to check_rate_limit to exceed the limit
      method_bucket = :"telegram_method_#{method}"
      for _ <- 1..30 do
        TelegramAPIHandler.check_rate_limit(method_bucket, 100, 30)
      end

      # Third call should be rate limited and delayed
      start_time = System.monotonic_time(:millisecond)
      assert {:ok, 2} = TelegramAPIHandler.with_rate_limit(params, method, test_fun)
      end_time = System.monotonic_time(:millisecond)

      # Verify that the third call was delayed
      assert end_time - start_time >= 50, "Rate limiting did not delay the request"
    end

    test "applies chat-specific rate limiting" do
      # Create a test function that counts calls
      Process.put(:call_count, 0)
      test_fun = fn ->
        count = Process.get(:call_count, 0)
        Process.put(:call_count, count + 1)
        {:ok, count}
      end

      # Call the function multiple times in quick succession with the same chat_id
      params = %{chat_id: 123456789}
      method = "sendMessage"

      # First call should go through immediately
      assert {:ok, 0} = TelegramAPIHandler.with_rate_limit(params, method, test_fun)

      # For the second call, we'll manually set the chat-specific rate limit to be exceeded
      chat_bucket = :"telegram_chat_#{params.chat_id}"
      # Exceed the chat-specific rate limit
      TelegramAPIHandler.check_rate_limit(chat_bucket, 100, 1)

      # Second call should be rate limited and delayed
      start_time = System.monotonic_time(:millisecond)
      assert {:ok, 1} = TelegramAPIHandler.with_rate_limit(params, method, test_fun)
      end_time = System.monotonic_time(:millisecond)

      # Verify that the second call was delayed
      assert end_time - start_time >= 50, "Chat-specific rate limiting did not delay the request"
    end
  end

  describe "with_retries/2" do
    test "retries the function on retryable errors" do
      # Create a function that fails with a retryable error on first call
      Process.put(:call_count, 0)
      test_fun = fn ->
        count = Process.get(:call_count, 0)
        Process.put(:call_count, count + 1)

        if count == 0 do
          {:error, "Bad Gateway"}
        else
          {:ok, "success"}
        end
      end

      assert {:ok, "success"} = TelegramAPIHandler.with_retries(
        test_fun,
        [initial_delay: 100, max_delay: 200]
      )

      assert Process.get(:call_count) == 2
    end

    test "does not retry on non-retryable errors" do
      # Create a function that fails with a non-retryable error
      Process.put(:call_count, 0)
      test_fun = fn ->
        count = Process.get(:call_count, 0)
        Process.put(:call_count, count + 1)

        {:error, "chat not found"}
      end

      assert {:error, _} = TelegramAPIHandler.with_retries(
        test_fun,
        [initial_delay: 100, max_delay: 200]
      )

      assert Process.get(:call_count) == 1
    end

    test "gives up after max retries" do
      # Create a function that always fails with a retryable error
      Process.put(:call_count, 0)
      test_fun = fn ->
        count = Process.get(:call_count, 0)
        Process.put(:call_count, count + 1)

        {:error, "Bad Gateway"}
      end

      assert {:error, _} = TelegramAPIHandler.with_retries(
        test_fun,
        [max_retries: 2, initial_delay: 100, max_delay: 200]
      )

      assert Process.get(:call_count) == 3  # Initial call + 2 retries
    end
  end

  describe "check_rate_limit/3" do
    test "allows requests under the limit" do
      bucket = :test_limit
      scale_ms = 1000
      limit = 3

      assert :ok = TelegramAPIHandler.check_rate_limit(bucket, scale_ms, limit)
      assert :ok = TelegramAPIHandler.check_rate_limit(bucket, scale_ms, limit)
      assert :ok = TelegramAPIHandler.check_rate_limit(bucket, scale_ms, limit)
    end

    test "rate limits requests over the limit" do
      bucket = :test_limit2
      scale_ms = 1000
      limit = 1

      assert :ok = TelegramAPIHandler.check_rate_limit(bucket, scale_ms, limit)

      # Next request should be rate limited
      case TelegramAPIHandler.check_rate_limit(bucket, scale_ms, limit) do
        :ok -> flunk("Request should have been rate limited")
        {:error, wait_time} -> assert wait_time > 0
      end
    end
  end

  describe "reset_all/0" do
    test "resets all rate limiters" do
      # Set up some rate limiters
      bucket1 = :telegram_global
      bucket2 = :telegram_chat_123
      scale_ms = 1000
      limit = 1

      # Use up the rate limits
      TelegramAPIHandler.check_rate_limit(bucket1, scale_ms, limit)
      TelegramAPIHandler.check_rate_limit(bucket1, scale_ms, limit)
      
      # Reset all rate limiters
      TelegramAPIHandler.reset_all()
      
      # Sleep a bit to ensure Hammer has time to process the reset
      Process.sleep(100)

      # Should be able to make requests again
      assert :ok = TelegramAPIHandler.check_rate_limit(bucket1, scale_ms, limit)
      assert :ok = TelegramAPIHandler.check_rate_limit(bucket2, scale_ms, limit)
    end
  end

  describe "request_with_handling/3" do
    test "combines rate limiting and retries" do
      # Create a mock lens module for testing
      defmodule MockLens do
        def focus(params, _opts \\ []) do
          count = Process.get(:request_count, 0)
          Process.put(:request_count, count + 1)

          if count == 0 do
            # First call fails with a retryable error
            {:error, "Bad Gateway"}
          else
            # Subsequent calls succeed
            {:ok, %{message_id: 123, text: params[:text] || "test"}}
          end
        end
      end

      # Reset the counter
      Process.put(:request_count, 0)

      # Call the function with our mock lens
      assert {:ok, result} = TelegramAPIHandler.request_with_handling(
        MockLens,
        %{text: "Hello, world!"},
        [initial_delay: 100, max_delay: 200]
      )

      # Verify the result
      assert result.message_id == 123
      assert result.text == "Hello, world!"
      assert Process.get(:request_count) == 2  # Initial call + 1 retry
    end

    test "skips rate limiting when requested" do
      # Create a mock lens module for testing
      defmodule MockLensForSkipRateLimit do
        def focus(_params, _opts \\ []) do
          {:ok, %{message_id: 123, text: "test"}}
        end
      end

      # Call the function with our mock lens and skip_rate_limit option
      assert {:ok, result} = TelegramAPIHandler.request_with_handling(
        MockLensForSkipRateLimit,
        %{},
        [skip_rate_limit: true]
      )

      # Verify the result
      assert result.message_id == 123
    end

    test "skips retries when requested" do
      # Create a mock lens module for testing
      defmodule MockLensForSkipRetries do
        def focus(_params, _opts \\ []) do
          count = Process.get(:request_count, 0)
          Process.put(:request_count, count + 1)

          # Always fail with a retryable error
          {:error, "Bad Gateway"}
        end
      end

      # Reset the counter
      Process.put(:request_count, 0)

      # Call the function with our mock lens and skip_retries option
      assert {:error, _} = TelegramAPIHandler.request_with_handling(
        MockLensForSkipRetries,
        %{},
        [skip_retries: true]
      )

      # Verify that it didn't retry
      assert Process.get(:request_count) == 1
    end
  end
end

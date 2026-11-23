defmodule Lux.Integrations.Telegram.ErrorHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.ErrorHandler

  describe "with_retry/2" do
    test "returns success without retry" do
      result = ErrorHandler.with_retry(fn -> {:ok, "done"} end)
      assert result == {:ok, "done"}
    end

    test "retries on retryable error and succeeds" do
      test_pid = self()

      func = fn ->
        if System.get_env("TELEGRAM_TEST_RETRY") == "1" do
          send(test_pid, :retried)
          {:ok, "success"}
        else
          System.put_env("TELEGRAM_TEST_RETRY", "1")
          {:error, %{code: 500, description: "Server Error"}}
        end
      end

      try do
        result = ErrorHandler.with_retry(func, max_retries: 3, initial_delay_ms: 1)
        assert result == {:ok, "success"}
        assert_received :retried
      after
        System.delete_env("TELEGRAM_TEST_RETRY")
      end
    end

    test "does not retry on fatal error" do
      func = fn -> {:error, %{code: 401, description: "Unauthorized"}} end

      result = ErrorHandler.with_retry(func, max_retries: 3, initial_delay_ms: 1)
      assert {:error, error} = result
      assert error.code == 401
      assert error.type == :fatal
    end

    test "exhausts retries and returns error" do
      func = fn -> {:error, %{code: 500, description: "Server Error"}} end

      result = ErrorHandler.with_retry(func, max_retries: 2, initial_delay_ms: 1)
      assert {:error, error} = result
      assert error.code == 500
      assert error.type == :retryable
    end
  end

  describe "classify_error/1" do
    test "classifies 429 as retryable" do
      assert :retryable = ErrorHandler.classify_error(%{code: 429, description: "Too Many Requests"})
    end

    test "classifies 5xx as retryable" do
      assert :retryable = ErrorHandler.classify_error(%{code: 500, description: "Server Error"})
      assert :retryable = ErrorHandler.classify_error(%{code: 502, description: "Bad Gateway"})
      assert :retryable = ErrorHandler.classify_error(%{code: 503, description: "Service Unavailable"})
    end

    test "classifies 4xx as fatal" do
      assert :fatal = ErrorHandler.classify_error(%{code: 400, description: "Bad Request"})
      assert :fatal = ErrorHandler.classify_error(%{code: 401, description: "Unauthorized"})
      assert :fatal = ErrorHandler.classify_error(%{code: 403, description: "Forbidden"})
      assert :fatal = ErrorHandler.classify_error(%{code: 404, description: "Not Found"})
    end

    test "classifies unknown as retryable" do
      assert :retryable = ErrorHandler.classify_error(%{code: 0, description: "Unknown"})
    end
  end

  describe "retryable?/1" do
    test "returns true for retryable errors" do
      assert ErrorHandler.retryable?(%{code: 429, description: "Too Many Requests"})
      assert ErrorHandler.retryable?(%{code: 500, description: "Server Error"})
    end

    test "returns false for fatal errors" do
      refute ErrorHandler.retryable?(%{code: 401, description: "Unauthorized"})
      refute ErrorHandler.retryable?(%{code: 400, description: "Bad Request"})
    end
  end

  describe "extract_retry_after/1" do
    test "extracts retry_after from parameters" do
      assert 5 = ErrorHandler.extract_retry_after(%{parameters: %{retry_after: 5}})
    end

    test "returns default 1 when no retry_after" do
      assert 1 = ErrorHandler.extract_retry_after(%{code: 429})
      assert 1 = ErrorHandler.extract_retry_after(%{})
    end
  end

  describe "backoff_delay/3" do
    test "calculates exponential backoff" do
      assert 1000 = ErrorHandler.backoff_delay(0, 1000, 60_000)
      assert 2000 = ErrorHandler.backoff_delay(1, 1000, 60_000)
      assert 4000 = ErrorHandler.backoff_delay(2, 1000, 60_000)
      assert 8000 = ErrorHandler.backoff_delay(3, 1000, 60_000)
    end

    test "caps at max_delay" do
      assert 60_000 = ErrorHandler.backoff_delay(10, 1000, 60_000)
    end
  end

  describe "format_error/1" do
    test "formats Telegram error response" do
      response = %{
        "ok" => false,
        "error_code" => 429,
        "description" => "Too Many Requests"
      }

      error = ErrorHandler.format_error(response)
      assert error.type == :retryable
      assert error.code == 429
      assert error.description == "Too Many Requests"
      assert error.retry_after == 1
    end

    test "formats error with retry_after" do
      response = %{
        "ok" => false,
        "error_code" => 429,
        "description" => "Too Many Requests",
        "parameters" => %{"retry_after" => 5}
      }

      error = ErrorHandler.format_error(response)
      assert error.retry_after == 5
    end

    test "formats map error" do
      error = ErrorHandler.format_error(%{code: 401, description: "Unauthorized"})
      assert error.type == :fatal
      assert error.code == 401
      assert error.description == "Unauthorized"
    end

    test "formats unknown error" do
      error = ErrorHandler.format_error(:some_unknown_error)
      assert error.type == :fatal
      assert error.code == 0
      assert is_binary(error.description)
    end
  end
end
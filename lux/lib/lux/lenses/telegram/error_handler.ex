defmodule Lux.Lenses.Telegram.ErrorHandler do
  @moduledoc """
  Error handler for Telegram Bot API requests.

  This module provides error handling and retry logic for Telegram Bot API requests.
  It categorizes errors and determines whether they are retryable.
  """

  require Logger

  @doc """
  Handles errors from the Telegram Bot API.

  ## Parameters

  - `error`: The error message or response from the Telegram API

  ## Returns

  - `{:retry, delay_ms}` if the error is retryable
  - `{:error, reason}` if the error is not retryable
  """
  def handle_error(error) when is_binary(error) do
    cond do
      # Network errors - retry with backoff
      String.contains?(error, "timeout") ->
        Logger.warn("Network timeout error detected, will retry: #{inspect(error)}")
        {:retry, 1000}

      String.contains?(error, "connection") ->
        Logger.warn("Connection error detected, will retry: #{inspect(error)}")
        {:retry, 1000}

      String.contains?(error, "network") ->
        Logger.warn("Network error detected, will retry: #{inspect(error)}")
        {:retry, 1000}

      # Rate limiting errors - retry after specified time
      String.contains?(error, "Too Many Requests") ->
        # Extract retry_after from error message if available
        case Regex.run(~r/retry after (\d+)/, error) do
          [_, seconds] ->
            delay = String.to_integer(seconds) * 1000
            Logger.warn("Rate limit error detected, will retry after #{delay}ms: #{inspect(error)}")
            {:retry, delay}

          _ ->
            # Default to 5 seconds if we can't extract the retry time
            Logger.warn("Rate limit error detected, will retry after 5000ms: #{inspect(error)}")
            {:retry, 5000}
        end

      # Server errors - retry with backoff
      String.contains?(error, "Bad Gateway") ->
        Logger.warn("Bad Gateway error detected, will retry: #{inspect(error)}")
        {:retry, 2000}

      String.contains?(error, "Service Unavailable") ->
        Logger.warn("Service Unavailable error detected, will retry: #{inspect(error)}")
        {:retry, 3000}

      String.contains?(error, "Gateway Timeout") ->
        Logger.warn("Gateway Timeout error detected, will retry: #{inspect(error)}")
        {:retry, 4000}

      # Bot was blocked or kicked - don't retry
      String.contains?(error, "bot was blocked") ->
        Logger.error("Bot was blocked error, will not retry: #{inspect(error)}")
        {:error, :bot_blocked}

      String.contains?(error, "bot was kicked") ->
        Logger.error("Bot was kicked error, will not retry: #{inspect(error)}")
        {:error, :bot_kicked}

      # Chat not found - don't retry
      String.contains?(error, "chat not found") ->
        Logger.error("Chat not found error, will not retry: #{inspect(error)}")
        {:error, :chat_not_found}

      # Message is too long - don't retry
      String.contains?(error, "message is too long") ->
        Logger.error("Message too long error, will not retry: #{inspect(error)}")
        {:error, :message_too_long}

      # Default - don't retry
      true ->
        Logger.error("Unhandled error, will not retry: #{inspect(error)}")
        {:error, error}
    end
  end

  def handle_error(%{"error_code" => code, "description" => description}) do
    Logger.warn("Telegram API error code #{code}: #{description}")
    handle_error_code(code, description)
  end

  def handle_error(%{"ok" => false, "description" => description}) do
    Logger.warn("Telegram API error: #{description}")
    handle_error(description)
  end

  def handle_error(error) do
    # For any other error format, don't retry
    Logger.error("Unknown error format, will not retry: #{inspect(error)}")
    {:error, error}
  end

  @doc """
  Executes a function with retry logic for Telegram API requests.

  ## Parameters

  - `fun`: The function to execute
  - `opts`: Options for retries
    - `max_retries`: Maximum number of retry attempts (default: 3)
    - `initial_delay`: Initial delay in milliseconds (default: 1000)
    - `max_delay`: Maximum delay in milliseconds (default: 30000)

  ## Returns

  Returns the result of the function or an error after all retries are exhausted.
  """
  def with_retries(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    initial_delay = Keyword.get(opts, :initial_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30000)

    do_with_retries(fun, max_retries, initial_delay, max_delay, 0)
  end

  # Private helpers

  defp do_with_retries(fun, max_retries, initial_delay, max_delay, retry_count) do
    case fun.() do
      {:ok, result} ->
        if retry_count > 0 do
          Logger.info("Request succeeded after #{retry_count} retries")
        end
        {:ok, result}

      {:error, error} ->
        if retry_count < max_retries do
          case handle_error(error) do
            {:retry, delay} ->
              # Calculate exponential backoff with jitter
              backoff_delay = calculate_backoff(initial_delay, max_delay, retry_count)
              # Use the larger of the two delays
              actual_delay = max(delay, backoff_delay)

              Logger.info("Retry attempt #{retry_count + 1}/#{max_retries} after #{actual_delay}ms")
              Process.sleep(actual_delay)
              do_with_retries(fun, max_retries, initial_delay, max_delay, retry_count + 1)

            {:error, reason} ->
              # Non-retryable error
              Logger.error("Non-retryable error encountered: #{inspect(reason)}")
              {:error, reason}
          end
        else
          # Max retries reached
          Logger.error("Max retries (#{max_retries}) reached, giving up: #{inspect(error)}")
          {:error, error}
        end
    end
  end

  defp calculate_backoff(initial_delay, max_delay, retry_count) do
    # Exponential backoff: initial_delay * 2^retry_count
    delay = initial_delay * :math.pow(2, retry_count)
    # Add jitter: random value between 0 and 25% of the delay
    jitter = :rand.uniform(trunc(delay * 0.25))
    # Cap at max_delay
    trunc(min(delay + jitter, max_delay))
  end

  defp handle_error_code(code, description) when code in [420, 429] do
    # Rate limiting errors
    case Regex.run(~r/retry after (\d+)/, description) do
      [_, seconds] ->
        delay = String.to_integer(seconds) * 1000
        Logger.warn("Rate limit error (code #{code}), will retry after #{delay}ms")
        {:retry, delay}

      _ ->
        # Default to 5 seconds if we can't extract the retry time
        Logger.warn("Rate limit error (code #{code}), will retry after 5000ms")
        {:retry, 5000}
    end
  end

  defp handle_error_code(code, _description) when code >= 500 and code < 600 do
    Logger.warn("Server error (code #{code}), will retry after 2000ms")
    {:retry, 2000}
  end

  defp handle_error_code(code, description) do
    Logger.warn("Unhandled error code #{code}, delegating to text-based handler")
    # For other error codes, use the text-based handler
    handle_error(description)
  end
end

defmodule Lux.Integrations.Telegram.ErrorHandler do
  @moduledoc """
  Error handling and retry logic for the Telegram Bot API.

  Provides:
  - Retry with exponential backoff for transient failures
  - Telegram-specific error classification (retryable vs fatal)
  - Structured error types with context
  - Rate-limit (429) handling with `retry_after` support

  ## Error Classification

  Telegram Bot API errors are classified as:

  - `:retryable` — transient errors (network, 5xx, 429 rate limit)
  - `:fatal` — permanent errors (401 unauthorized, 400 bad request, 403 forbidden)

  ## Retry Policy

  Retries use exponential backoff with jitter:
  - Initial delay: 1 second
  - Max retries: 3 (configurable)
  - Backoff multiplier: 2
  - Max delay: 60 seconds
  """

  require Logger

  @type error_type :: :retryable | :fatal
  @type telegram_error :: %{
          required(:type) => error_type(),
          required(:code) => non_neg_integer(),
          required(:description) => String.t(),
          optional(:retry_after) => non_neg_integer()
        }

  @default_max_retries 3
  @default_initial_delay_ms 1_000
  @default_max_delay_ms 60_000
  @backoff_multiplier 2

  @doc """
  Executes a function with retry logic.

  The function must return `{:ok, result}` or `{:error, reason}`.
  Retries on `:retryable` errors with exponential backoff.

  ## Options

  - `:max_retries` — maximum retry attempts (default: 3)
  - `:initial_delay_ms` — initial backoff delay (default: 1000)
  - `:max_delay_ms` — maximum backoff delay (default: 60000)

  ## Examples

      iex> ErrorHandler.with_retry(fn -> {:ok, "done"} end)
      {:ok, "done"}
  """
  @spec with_retry((-> {:ok, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_retry(func, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    initial_delay = Keyword.get(opts, :initial_delay_ms, @default_initial_delay_ms)
    max_delay = Keyword.get(opts, :max_delay_ms, @default_max_delay_ms)

    do_with_retry(func, max_retries, initial_delay, max_delay, 0)
  end

  @doc """
  Classifies a Telegram API error as retryable or fatal.

  ## Examples

      iex> ErrorHandler.classify_error(%{code: 429, description: "Too Many Requests"})
      :retryable

      iex> ErrorHandler.classify_error(%{code: 401, description: "Unauthorized"})
      :fatal
  """
  @spec classify_error(map()) :: error_type()
  def classify_error(%{code: code}) when code in [429, 500, 502, 503, 504], do: :retryable
  def classify_error(%{code: code}) when code >= 500, do: :retryable
  def classify_error(%{code: code}) when code in [400, 401, 403, 404], do: :fatal
  def classify_error(%{code: code}) when code >= 400 and code < 500, do: :fatal
  def classify_error(_), do: :retryable

  @doc """
  Checks if an error is retryable.

  ## Examples

      iex> ErrorHandler.retryable?(%{code: 429, description: "Too Many Requests"})
      true

      iex> ErrorHandler.retryable?(%{code: 401, description: "Unauthorized"})
      false
  """
  @spec retryable?(map()) :: boolean()
  def retryable?(error) do
    classify_error(error) == :retryable
  end

  @doc """
  Extracts the `retry_after` value from a 429 error response.

  Returns the number of seconds to wait, or a default of 1 second.

  ## Examples

      iex> ErrorHandler.extract_retry_after(%{parameters: %{retry_after: 5}})
      5

      iex> ErrorHandler.extract_retry_after(%{code: 429})
      1
  """
  @spec extract_retry_after(map()) :: non_neg_integer()
  def extract_retry_after(%{parameters: %{retry_after: seconds}}) when is_integer(seconds) do
    seconds
  end

  def extract_retry_after(%{"parameters" => %{"retry_after" => seconds}}) when is_integer(seconds) do
    seconds
  end

  def extract_retry_after(%{retry_after: seconds}) when is_integer(seconds) do
    seconds
  end

  def extract_retry_after(%{"retry_after" => seconds}) when is_integer(seconds) do
    seconds
  end

  def extract_retry_after(_), do: 1

  @doc """
  Calculates the backoff delay for a given retry attempt.

  Uses exponential backoff with a cap at `max_delay`.

  ## Examples

      iex> ErrorHandler.backoff_delay(0, 1000, 60000)
      1000

      iex> ErrorHandler.backoff_delay(2, 1000, 60000)
      4000
  """
  @spec backoff_delay(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          non_neg_integer()
  def backoff_delay(attempt, initial_delay, max_delay) do
    delay = initial_delay * Integer.pow(@backoff_multiplier, attempt)
    min(delay, max_delay)
  end

  @doc """
  Formats a Telegram error response into a structured error map.

  ## Examples

      iex> ErrorHandler.format_error(%{"ok" => false, "error_code" => 429, "description" => "Too Many Requests"})
      %{type: :retryable, code: 429, description: "Too Many Requests", retry_after: 1}
  """
  @spec format_error(map()) :: telegram_error()
  def format_error(%{"ok" => false, "error_code" => code, "description" => description} = response) do
    error = %{
      type: classify_error(%{code: code}),
      code: code,
      description: description
    }

    if code == 429 do
      retry_after = extract_retry_after(response)
      Map.put(error, :retry_after, retry_after)
    else
      error
    end
  end

  def format_error(%{code: code, description: description} = error) do
    formatted = %{
      type: classify_error(%{code: code}),
      code: code,
      description: description
    }

    if code == 429 do
      retry_after = extract_retry_after(error)
      Map.put(formatted, :retry_after, retry_after)
    else
      formatted
    end
  end

  def format_error(other) do
    %{
      type: :fatal,
      code: 0,
      description: inspect(other)
    }
  end

  # Private functions

  defp do_with_retry(func, retries_left, initial_delay, max_delay, attempt) do
    case func.() do
      {:ok, _result} = success ->
        success

      {:error, reason} ->
        if retryable?(reason) and retries_left > 0 do
          delay = calculate_delay(reason, attempt, initial_delay, max_delay)

          Logger.warning(
            "Telegram API error (attempt #{attempt + 1}/#{retries_left + attempt + 1}): " <>
              "#{reason[:description] || inspect(reason)}. Retrying in #{delay}ms..."
          )

          Process.sleep(delay)
          do_with_retry(func, retries_left - 1, initial_delay, max_delay, attempt + 1)
        else
          Logger.error(
            "Telegram API error (attempt #{attempt + 1}): " <>
              "#{reason[:description] || inspect(reason)}. Not retrying."
          )

          {:error, format_error(reason)}
        end
    end
  end

  defp calculate_delay(reason, attempt, initial_delay, max_delay) do
    if reason[:code] == 429 do
      # Use retry_after from Telegram for rate limits
      retry_after_seconds = extract_retry_after(reason)
      retry_after_ms = retry_after_seconds * 1000
      min(retry_after_ms, max_delay)
    else
      backoff_delay(attempt, initial_delay, max_delay)
    end
  end
end
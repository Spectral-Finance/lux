defmodule Lux.Integrations.Telegram.Retry do
  @moduledoc """
  Retry wrapper module for Telegram Bot API requests with exponential backoff.

  Handles transient errors by retrying failed requests with increasing delays.

  ## Retry Policy

  - Retries on 429 (Too Many Requests) using the Retry-After header value
  - Retries on 500, 502, 503, 504 server errors with exponential backoff
  - Does NOT retry 400, 401, 403, 404 client errors
  - Does NOT retry successful responses

  ## Configuration

  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:base_delay` - Base delay in milliseconds for exponential backoff (default: 1000)
  - `:max_delay` - Maximum delay in milliseconds (default: 30000)

  ## Usage

      Retry.with_retry(fn ->
        Client.request(:post, "/sendMessage", opts)
      end)

      Retry.with_retry(fn ->
        Client.request(:post, "/sendMessage", opts)
      end, max_retries: 5, base_delay: 500)
  """

  require Logger

  @default_max_retries 3
  @default_base_delay 1_000
  @default_max_delay 30_000

  @retryable_status_codes [429, 500, 502, 503, 504]
  @non_retryable_status_codes [400, 401, 403, 404]

  @doc """
  Executes the given function with retry logic.

  The function should return `{:ok, result}` on success or `{:error, reason}` on failure.
  Retries are only attempted for transient/server errors.

  ## Options

  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:base_delay` - Base delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay cap in milliseconds (default: 30000)

  ## Examples

      {:ok, result} = Retry.with_retry(fn ->
        Client.request(:post, "/sendMessage", opts)
      end)

      {:error, reason} = Retry.with_retry(fn ->
        Client.request(:post, "/sendMessage", bad_opts)
      end, max_retries: 5)
  """
  @spec with_retry((() -> {:ok, any()} | {:error, any()}), keyword()) ::
          {:ok, any()} | {:error, any()}
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)

    do_retry(fun, 0, max_retries, base_delay, max_delay)
  end

  defp do_retry(fun, attempt, max_retries, base_delay, max_delay) do
    case fun.() do
      {:ok, _} = success ->
        success

      {:error, {status, _} = error} when status in @non_retryable_status_codes ->
        {:error, error}

      {:error, :invalid_token} = error ->
        error

      {:error, {429, %{"retry_after" => retry_after}}} when attempt < max_retries ->
        delay = retry_after * 1_000
        Logger.warning("Rate limited by Telegram API. Retrying in #{delay}ms (attempt #{attempt + 1}/#{max_retries})")
        sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)

      {:error, {429, %{"parameters" => %{"retry_after" => retry_after}}}} when attempt < max_retries ->
        delay = retry_after * 1_000
        Logger.warning("Rate limited by Telegram API. Retrying in #{delay}ms (attempt #{attempt + 1}/#{max_retries})")
        sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)

      {:error, {status, _}} when status in @retryable_status_codes and attempt < max_retries ->
        delay = calculate_delay(attempt, base_delay, max_delay)
        Logger.warning("Telegram API error (HTTP #{status}). Retrying in #{delay}ms (attempt #{attempt + 1}/#{max_retries})")
        sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)

      {:error, %{__exception__: true}} = error when attempt < max_retries ->
        delay = calculate_delay(attempt, base_delay, max_delay)
        Logger.warning("Network error. Retrying in #{delay}ms (attempt #{attempt + 1}/#{max_retries})")
        sleep(delay)
        do_retry(fun, attempt + 1, max_retries, base_delay, max_delay)

      error ->
        error
    end
  end

  defp calculate_delay(attempt, base_delay, max_delay) do
    delay = base_delay * Integer.pow(2, attempt)
    jitter = :rand.uniform() * 0.5 + 0.5
    min(round(delay * jitter), max_delay)
  end

  # Allows overriding in tests
  defp sleep(ms) do
    Process.sleep(ms)
  end
end

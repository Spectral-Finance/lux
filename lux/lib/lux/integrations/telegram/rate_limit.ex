defmodule Lux.Integrations.Telegram.RateLimit do
  @moduledoc """
  Rate-limit and retry helpers for Telegram Bot API requests.

  Telegram can return a 429 response with `parameters.retry_after` when a bot
  should pause before retrying. Other transient failures use exponential
  backoff so callers can keep a single request path for resilient delivery.
  """

  @retryable_statuses [408, 425, 429]

  @doc """
  Returns true when an HTTP status is safe to retry.
  """
  @spec retryable_status?(integer() | atom()) :: boolean()
  def retryable_status?(status) when status in @retryable_statuses, do: true
  def retryable_status?(status) when is_integer(status) and status >= 500 and status <= 599, do: true
  def retryable_status?(_status), do: false

  @doc """
  Calculates the retry delay in milliseconds.

  Telegram's `retry_after` value is seconds, so it is converted to
  milliseconds. When it is not present, the helper falls back to exponential
  backoff using the zero-based attempt count.
  """
  @spec retry_delay_ms(integer() | atom(), term(), term(), non_neg_integer(), keyword()) ::
          non_neg_integer()
  def retry_delay_ms(status, body, headers, attempt, opts \\ [])

  def retry_delay_ms(429, body, headers, attempt, opts) do
    retry_after_ms(body, headers) || exponential_backoff_ms(attempt, opts)
  end

  def retry_delay_ms(_status, _body, _headers, attempt, opts) do
    exponential_backoff_ms(attempt, opts)
  end

  @doc """
  Extracts Telegram's `retry_after` value from the body or response headers.
  """
  @spec retry_after_ms(term(), term()) :: non_neg_integer() | nil
  def retry_after_ms(%{"parameters" => %{"retry_after" => seconds}}, _headers),
    do: seconds_to_ms(seconds)

  def retry_after_ms(_body, headers), do: headers |> retry_after_header() |> seconds_to_ms()

  defp exponential_backoff_ms(attempt, opts) do
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 500)
    base_delay_ms * Integer.pow(2, attempt)
  end

  defp seconds_to_ms(seconds) when is_integer(seconds) and seconds >= 0, do: seconds * 1000

  defp seconds_to_ms(seconds) when is_binary(seconds) do
    case Integer.parse(seconds) do
      {value, ""} when value >= 0 -> value * 1000
      _ -> nil
    end
  end

  defp seconds_to_ms([seconds | _rest]), do: seconds_to_ms(seconds)

  defp seconds_to_ms(_seconds), do: nil

  defp retry_after_header(headers) when is_map(headers) do
    headers["retry-after"] || headers["Retry-After"]
  end

  defp retry_after_header(headers) when is_list(headers) do
    headers
    |> Enum.find_value(fn
      {key, value} when is_binary(key) ->
        if String.downcase(key) == "retry-after", do: value

      _ ->
        nil
    end)
  end

  defp retry_after_header(_headers), do: nil
end

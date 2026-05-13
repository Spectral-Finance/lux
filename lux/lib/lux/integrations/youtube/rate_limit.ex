defmodule Lux.Integrations.YouTube.RateLimit do
  @moduledoc """
  Retry and rate-limit helpers for YouTube Data API responses.
  """

  @retryable_reasons ~w(rateLimitExceeded userRateLimitExceeded backendError internalError)

  @doc """
  Returns true when a YouTube response should be retried.
  """
  @spec retryable_response?(integer(), term()) :: boolean()
  def retryable_response?(status, _body) when status in [408, 425, 429], do: true
  def retryable_response?(status, _body) when is_integer(status) and status >= 500 and status <= 599, do: true

  def retryable_response?(403, %{"error" => %{"errors" => errors}}) when is_list(errors) do
    Enum.any?(errors, fn error -> Map.get(error, "reason") in @retryable_reasons end)
  end

  def retryable_response?(_status, _body), do: false

  @doc """
  Calculates a retry delay in milliseconds from `Retry-After` or exponential backoff.
  """
  @spec retry_delay_ms(term(), non_neg_integer(), keyword()) :: non_neg_integer()
  def retry_delay_ms(headers, attempt, opts \\ []) do
    retry_after_ms(headers) || exponential_backoff_ms(attempt, opts)
  end

  @doc """
  Extracts `Retry-After` from response headers.
  """
  @spec retry_after_ms(term()) :: non_neg_integer() | nil
  def retry_after_ms(headers), do: headers |> retry_after_header() |> seconds_to_ms()

  defp exponential_backoff_ms(attempt, opts) do
    base_delay_ms = Keyword.get(opts, :base_delay_ms, 500)
    base_delay_ms * Integer.pow(2, attempt)
  end

  defp retry_after_header(headers) when is_map(headers) do
    headers
    |> Map.to_list()
    |> retry_after_header()
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

  defp seconds_to_ms(seconds) when is_integer(seconds) and seconds >= 0, do: seconds * 1000

  defp seconds_to_ms(seconds) when is_binary(seconds) do
    case Integer.parse(seconds) do
      {value, ""} when value >= 0 -> value * 1000
      _ -> nil
    end
  end

  defp seconds_to_ms([seconds | _rest]), do: seconds_to_ms(seconds)
  defp seconds_to_ms(_seconds), do: nil
end

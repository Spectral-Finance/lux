defmodule Lux.Telegram.Middleware.RateLimit do
  @moduledoc """
  Req response step middleware for Telegram Bot API rate limiting (HTTP 429).
  """

  @doc """
  Attaches rate limit middleware to a Req request struct.
  """
  def attach(%Req.Request{} = req, opts \\ []) do
    opts_list = if is_map(opts), do: Map.to_list(opts), else: opts || []
    filtered_opts = Keyword.take(opts_list, [:max_rate_limit_retries, :sleep_fun])

    req
    |> Req.Request.register_options([:max_rate_limit_retries, :sleep_fun])
    |> Req.Request.merge_options(filtered_opts)
    |> Req.Request.append_response_steps(telegram_rate_limit: &handle/1)
  end

  @doc """
  Handles response step for HTTP status 429 backoff and retry.
  """
  def handle({request, %Req.Response{status: 429} = response}) do
    retry_count = Req.Request.get_private(request, :telegram_rate_limit_retry_count, 0)
    max_retries = Req.Request.get_option(request, :max_rate_limit_retries, 3)

    if retry_count < max_retries do
      retry_after = extract_retry_after(response)
      sleep_fun = Req.Request.get_option(request, :sleep_fun, fn ms -> Process.sleep(ms) end)

      sleep_fun.(retry_after * 1000)

      request = Req.Request.put_private(request, :telegram_rate_limit_retry_count, retry_count + 1)
      {request, new_response} = Req.Request.run_request(%{request | halted: false})
      Req.Request.halt(request, new_response)
    else
      {request, response}
    end
  end

  def handle({request, response_or_exception}) do
    {request, response_or_exception}
  end

  @doc """
  Extracts `retry_after` (in seconds) from Telegram response JSON or Retry-After header.
  Clamps non-positive and invalid values to a minimum of 1 second.
  """
  def extract_retry_after(%Req.Response{} = response) do
    cond do
      val = extract_from_body(response.body) ->
        normalize_retry_after(val)

      val = extract_from_headers(response.headers) ->
        normalize_retry_after(val)

      true ->
        1
    end
  end

  def extract_retry_after(%{} = map) do
    cond do
      val = extract_from_body(map) ->
        normalize_retry_after(val)

      true ->
        1
    end
  end

  def extract_retry_after(_), do: 1

  defp extract_from_body(body) when is_map(body) do
    params = body["parameters"] || body[:parameters]

    cond do
      is_map(params) and (params["retry_after"] != nil or params[:retry_after] != nil) ->
        params["retry_after"] || params[:retry_after]

      body["retry_after"] != nil ->
        body["retry_after"]

      body[:retry_after] != nil ->
        body[:retry_after]

      true ->
        nil
    end
  end

  defp extract_from_body(_), do: nil

  defp extract_from_headers(headers) when is_map(headers) do
    Enum.find_value(headers, fn {k, v} ->
      if String.downcase(to_string(k)) == "retry-after", do: unwrap_header_value(v)
    end)
  end

  defp extract_from_headers(headers) when is_list(headers) do
    Enum.find_value(headers, fn
      {k, v} ->
        if String.downcase(to_string(k)) == "retry-after", do: unwrap_header_value(v)

      _ ->
        nil
    end)
  end

  defp extract_from_headers(_), do: nil

  defp unwrap_header_value([first | _]), do: first
  defp unwrap_header_value(val), do: val

  defp normalize_retry_after(val) when is_integer(val) do
    max(val, 1)
  end

  defp normalize_retry_after(val) when is_float(val) do
    max(trunc(val), 1)
  end

  defp normalize_retry_after(val) when is_binary(val) do
    case Integer.parse(val) do
      {num, _} ->
        max(num, 1)

      :error ->
        case Float.parse(val) do
          {num, _} -> max(trunc(num), 1)
          :error -> 1
        end
    end
  end

  defp normalize_retry_after(_), do: 1
end
